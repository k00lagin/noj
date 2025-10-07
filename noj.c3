module noj;
import std::io;
import std::io::file;
import std::core::string;
import std::os::process;

enum State : int {
	TEXT,
	STATEMENT,
	EXPRESSION,
	COMMENT,
	END
}

fn int transform(String input_path, String output_path) {
	if (!file::is_file(input_path)) {
		io::printn("Error: Input file does not exist");
		return 1;
	}

	char[] ? read_buffer = file::load_temp(input_path);

	if (catch excuse = read_buffer) {
		io::printn("Error: Failed to read input file");
		return 1;
	}

	const STATEMENT_START = "{%";
	const STATEMENT_END = "%}";
	const EXPR_START = "{{";
	const EXPR_END = "}}";
	const COMMENT_START = "{#";
	const COMMENT_END = "#}";
	const BRAKET_LEN = 2;

	State state = TEXT;
	DString output;
	output.append("import std::io;\n");
	output.append("import std::io::file;\n");
	output.append("import std::core::string;\n");
	output.append("fn String escape_html(String input) {\n");
	output.append("    DString result;\n");
	output.append("    for (usz i = 0; i < input.len; i++) {\n");
	output.append("        char c = input[i];\n");
	output.append("        switch (c) {\n");
	output.append("            case '<': result.append(\"&lt;\"); break;\n");
	output.append("            case '>': result.append(\"&gt;\"); break;\n");
	output.append("            case '&': result.append(\"&amp;\"); break;\n");
	output.append("            case '\"': result.append(\"&quot;\"); break;\n");
	output.append("            case '\\'': result.append(\"&#39;\"); break;\n");
	output.append("            default: result.append(c);\n");
	output.append("        }\n");
	output.append("    }\n");
	output.append("    return result.str_view();\n");
	output.append("}\n");
	output.append("fn void main() {\n");
	output.append("DString sb;\n");

	DString sb;

	usz i = 0;
	while (i < read_buffer.len) {
		State next_state = state;
		if (i + BRAKET_LEN < read_buffer.len) {
			if (state == TEXT) {
				if (read_buffer[i..i + EXPR_START.len - 1] == EXPR_START) {
					next_state = EXPRESSION;
					i += EXPR_START.len;
				}
				if (read_buffer[i..i + STATEMENT_START.len - 1] == STATEMENT_START) {
					next_state = STATEMENT;
					i += STATEMENT_START.len;
				}
				if (read_buffer[i..i + COMMENT_START.len - 1] == COMMENT_START) {
					next_state = COMMENT;
					i += COMMENT_START.len;
				}
			}

			if (state == EXPRESSION &&
					read_buffer[i..i + EXPR_END.len - 1] == EXPR_END) {
				next_state = TEXT;
				i += EXPR_END.len;
			}

			if (state == STATEMENT &&
					read_buffer[i..i + STATEMENT_END.len - 1] == STATEMENT_END) {
				next_state = TEXT;
				i += STATEMENT_END.len;
			}

			if (state == COMMENT &&
					read_buffer[i..i + COMMENT_END.len - 1] == COMMENT_END) {
				next_state = TEXT;
				i += COMMENT_END.len;
			}
		}
		if (i == read_buffer.len - 1) {
			next_state = END;
		}

		if (state == EXPRESSION && (next_state == TEXT || next_state == END)) {
			output.append("sb.append(escape_html(");
			output.append(sb.str_view().trim());
			output.append("));\n");
			sb.clear();
		}

		if (state == STATEMENT && (next_state == TEXT || next_state == END)) {
			output.append(sb.str_view().trim());
			output.append(";\n");
			sb.clear();
		}

		if (state == TEXT && (next_state != TEXT || next_state == END)) {
			String text = sb.str_view();
			bool has_backtick = false;
			for (usz j = 0; j < text.len; j++) {
				if (text[j] == '`') {
					has_backtick = true;
					break;
				}
			}
			
			if (!has_backtick) {
				output.append("sb.append(`");
				output.append(text);
				output.append("`);\n");
			} else {
				output.append("sb.append(\"");
				for (usz j = 0; j < text.len; j++) {
					char c = text[j];
					switch (c) {
						case '"': output.append("\\\""); break;
						case '\\': output.append("\\\\"); break;
						case '\n': output.append("\\n"); break;
						case '\r': output.append("\\r"); break;
						case '\t': output.append("\\t"); break;
						default: output.append(c);
					}
				}
				output.append("\");\n");
			}
			sb.clear();
		}

		if (state != COMMENT) {
			sb.append(read_buffer[i]);
		}

		if (next_state != state) {
			state = next_state;
		}
		i++;
	}

	output.append("File file = io::file::open(\"");
	output.append(output_path);
	output.append("\", \"w\") !!;\n");
	output.append("defer file.close() !!;\n");
	output.append("file.write(sb.str_view()) !!;\n");
	output.append("}\n");

	DString ir_path;
	ir_path.append(".build/");
	ir_path.append(output_path);
	ir_path.append(".c3");
	File file = file::open(ir_path.str_view(), "w") !!;
	defer file.close() !!;
	file.write(output.str_view()) !!;

	SubProcess worker = process::create({ "c3c", "compile-run", ir_path.str_view(), "-o", ".build/temp" }, {.inherit_environment = true}) !!;
	return 0;
}

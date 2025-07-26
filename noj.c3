import std::io;
import std::core::string;

char *current_path = "";
String input_path = "";
String output_path = "";

enum State : int {
	TEXT,
	STATEMENT,
	EXPRESSION,
	COMMENT,
	END
}

fn void print_help() {
  io::printn("Usage: noj -i <input_file> -o <output_file>");
}

fn char[] ? read_file(String filename, char[] buffer) {
  File file = file::open(filename, "r") !;

  defer(void) file.close();

  file.read(buffer) !;
  return buffer;
}

fn int main(String[] args) {
  current_path = args[0];

  if (args.len < 3) {
    io::printn("Error: Not enough arguments");
    print_help();
    return 1;
  }

  foreach (index, argument : args) {
    if (index == 0) continue;

    if (argument.starts_with("-i")) {
      input_path = args[index + 1];
    }

    if (argument.starts_with("-o")) {
      output_path = args[index + 1];
    }

    if (argument == "-h" || argument == "--help") {
      print_help();
      return 0;
    }
  }

  if (input_path == "") {
    io::printn("Error: Input file not specified");
    print_help();
    return 0;
  }

  if (output_path == "") {
    io::printn("Error: Output file not specified");
    print_help();
    return 1;
  }

  if (!io::file::is_file(input_path)) {
    io::printn("Error: Input file does not exist");
    return 1;
  }

  usz file_size = io::file::get_size(input_path) !!;
  char[] buffer = mem::new_array(char, file_size);
  defer free(buffer);
  char[] ? read_buffer = read_file(input_path, buffer);

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
	output.append("fn void main() {\n");
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
      output.append("io::print(");
      output.append(sb.str_view().trim());
      output.append(");\n");
      sb.clear();
    }

    if (state == STATEMENT && (next_state == TEXT || next_state == END)) {
      output.append(sb.str_view().trim());
      output.append(";\n");
      sb.clear();
    }

    if (state == TEXT && (next_state != TEXT || next_state == END)) {
      output.append("io::print(`");
      output.append(sb.str_view().trim());
      output.append("`);\n");
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

	output.append("}\n");

	DString ir_path;
	ir_path.append(output_path);
	ir_path.append(".c3");
  File file = io::file::open(ir_path.str_view(), "w") !!;
  defer file.close() !!;
  file.write(output.str_view()) !!;

  return 0;
}
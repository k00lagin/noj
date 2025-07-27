import noj;

fn void main() {
	noj::transform("./templates/markdown.md.noj", "markdown.md");
	noj::transform("./templates/index.html.noj", "index.html");
}
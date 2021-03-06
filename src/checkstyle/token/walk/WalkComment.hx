package checkstyle.token.walk;

class WalkComment {
	public static function walkComment(stream:TokenStream, parent:TokenTree) {
		if (!stream.hasMore()) return;
		var progress:TokenStreamProgress = new TokenStreamProgress(stream);
		while (progress.streamHasChanged()) {
			switch (stream.token()) {
				case Comment(_), CommentLine(_):
					var comment:TokenTree = stream.consumeToken();
					parent.addChild(comment);
				default:
					return;
			}
		}
	}
}
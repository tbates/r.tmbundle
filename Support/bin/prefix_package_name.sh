[[ -n "$TM_SELECTED_TEXT" ]] && echo "Please unselect first." && exit_show_tool_tip

LINE=$(cat | perl -e '
	$line=$ENV{"TM_CURRENT_LINE"};$col=$ENV{"TM_LINE_INDEX"};
	$lineL=substr($line,0,$col);
	$lineR=substr($line,$col);
	$lineL=~s/(?=[\$`\\])/\\/g;
	$lineR=~s/(?=[\$`\\])/\\/g;
	print "$lineL\${0:}$lineR";
')
WORD=$(ruby -- <<-SCR1 
	require File.join(ENV["TM_SUPPORT_PATH"], "lib/current_word.rb")
	word = Word.current_word('\w._\(')
	print word
SCR1
)

WORD=$(echo -en "$WORD" | perl -pe 's/\([^\(]*$//')

[[ -z "$WORD" ]] && echo "No keyword found" && exit_show_tool_tip

"$TM_BUNDLE_SUPPORT"/bin/askRhelperDaemon.sh "@getPackageFor('$WORD')"
LIB=$(cat /tmp/textmate_Rhelper_out)
if [ -z "$LIB" ]; then
	echo -en "No package found."
	exit 206
fi

if [ `echo "$LIB" | wc -l` -gt 1 ]; then
	LIB=$(echo "$LIB" | sort -f | ruby -e '
		require File.join(ENV["TM_SUPPORT_PATH"], "lib/ui.rb")
		require File.join(ENV["TM_SUPPORT_PATH"], "lib/exit_codes.rb")
		words = STDIN.read().split("\n")
		index=TextMate::UI.menu(words)
		if index != nil
			print words[index]
		end
	')
fi
[[ -z $LIB ]] && exit 200


OUT="${LINE/$WORD/$LIB::$WORD}"
if [ `echo "$OUT" | grep -c "$LIB::"` -lt 1 ]; then
	echo "Please set the caret at the end of the function name and redo it."
	exit 206
fi
echo -n "$OUT"

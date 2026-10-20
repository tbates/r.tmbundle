require 'test/unit'
require 'rexml/document'

# Regression test for the knitr chunk-label rule in the R Markdown grammar.
# knitr treats a first header token containing `=` as an option, not a label,
# so `{r eval=FALSE}` must not match the label pattern at all. The pattern is
# read straight out of the grammar, so this fails if the rule ever regresses.
class TestRMarkdownKnitr < Test::Unit::TestCase
  GRAMMAR = File.expand_path('../../Syntaxes/R Markdown.tmLanguage', File.dirname(__FILE__))

  def setup
    match = nil
    REXML::Document.new(File.read(GRAMMAR)).elements.each('//dict') do |dict|
      fields = {}
      dict.elements.each('key') { |key| fields[key.text] = key.next_element.text }
      match = fields['match'] if fields['name'] == 'entity.name.function.knitr'
    end
    assert_not_nil(match, 'label rule (entity.name.function.knitr) missing from grammar')
    @label = Regexp.new(match)
  end

  def label_of(header)
    m = @label.match(header)
    m && m[1]
  end

  def test_label_before_options
    assert_equal('setup', label_of('{r setup, include=FALSE}'))
  end

  def test_option_first_token_has_no_label
    assert_nil(label_of('{r eval=FALSE}'))
  end

  def test_label_with_value_has_no_label
    assert_nil(label_of('{r label=foo}'))
  end

  def test_empty_label_has_no_label
    assert_nil(label_of('{r, eval = FALSE}'))
  end

  def test_uppercase_engine
    assert_equal('plot-1', label_of('{R plot-1}'))
  end

  def test_label_with_space
    assert_equal('my chunk', label_of('{r my chunk, echo=TRUE}'))
  end
end

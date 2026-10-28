require 'test/unit'

# Regression: roxygen inline highlighting in Syntaxes/R.plist must cover
# both \eqn{} (inline) and \deqn{} (display) Rd math macros.
class TestRoxygenMath < Test::Unit::TestCase
  PLIST = File.expand_path('../../Syntaxes/R.plist', __dir__)

  def inline_patterns
    content = File.read(PLIST)
    content.scan(
      %r{<string>([^<]*)</string>\s*<key>name</key>\s*<string>markup\.raw\.inline\.roxygen</string>}
    ).map(&:first)
  end

  def matches_inline?(text)
    assert(!inline_patterns.empty?, 'no markup.raw.inline.roxygen pattern found in R.plist')
    inline_patterns.any? { |src| Regexp.new(src).match?(text) }
  end

  def test_eqn_matches
    assert(matches_inline?('\\eqn{x^2}'), 'expected \\eqn{} to be captured')
  end

  def test_deqn_matches
    assert(matches_inline?('\\deqn{x^2}'), 'expected \\deqn{} to be captured')
  end

  def test_other_macros_still_match
    assert(matches_inline?('\\code{foo}'), 'expected \\code{} to be captured')
    assert(matches_inline?('\\link{bar}'), 'expected \\link{} to be captured')
    assert(matches_inline?('\\dontrun{x}'), 'expected \\dontrun{} to be captured')
  end
end

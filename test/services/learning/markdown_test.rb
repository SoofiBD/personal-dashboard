require "test_helper"

class Learning::MarkdownTest < ActiveSupport::TestCase
  test "formats markdown and removes executable markup" do
    html = Learning::Markdown.render(<<~MD, resource_id: "algorithms--array")
      ## Heading

      **Bold** and `inline`.

      - First
      - Second

      ```ruby
      puts "<script>example</script>"
      ```

      <script>alert('unsafe')</script>
      <InDocAd />
      import Example from './example.md'

      [Unsafe](javascript:alert(1))
    MD
    doc = Nokogiri::HTML.fragment(html)
    assert_equal "Heading", doc.at_css("h2").text
    assert_equal "Bold", doc.at_css("strong").text
    assert_equal 2, doc.css("li").size
    assert_includes doc.at_css("pre code").text, "<script>example</script>"
    assert_empty doc.css("script, InDocAd")
    assert_empty doc.css('a[href^="javascript:"]')
    assert_not_includes doc.text, "import Example"
  end

  test "all bundled documents render" do
    Learning::Catalog.resources.each do |entry|
      html = Learning::Markdown.render(Learning::Catalog::ROOT.join("#{entry.fetch("id")}.md").read, resource_id: entry.fetch("id"))
      assert html.html_safe?
      assert_empty Nokogiri::HTML.fragment(html).css("script, iframe, img")
    end
  end
end

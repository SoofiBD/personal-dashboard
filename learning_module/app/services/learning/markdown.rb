module Learning
  class Markdown
    TAGS = %w[h1 h2 h3 h4 h5 h6 p br hr strong em del ul ol li blockquote pre code table thead tbody tr th td a].freeze

    def self.render(text, resource_id:)
      # Remove site-only MDX directives without changing fenced code examples.
      fence = nil
      source = text.lines.filter_map do |line|
        if (match = line.match(/^\s*(`{3,}|~{3,})/))
          marker = match[1]
          if fence.nil?
            fence = marker
          elsif marker[0] == fence[0] && marker.length >= fence.length
            fence = nil
          end
          next line
        end
        next line if fence
        next if line.match?(/^\s*import\s+.+\s+from\s+['"]/) || line.match?(/^\s*:::/)

        line
      end.join
      renderer = Redcarpet::Render::HTML.new(filter_html: true, no_images: true, with_toc_data: true)
      html = Redcarpet::Markdown.new(renderer, tables: true, fenced_code_blocks: true, strikethrough: true, autolink: true, no_intra_emphasis: true).render(source)
      fragment = Nokogiri::HTML.fragment(html)
      base = URI("https://www.techinterviewhandbook.org/#{resource_id.gsub("--", "/")}")
      fragment.css("a[href]").each do |link|
        href = link["href"]
        next if href.start_with?("#")

        begin
          uri = URI.join(base.to_s, href)
          if %w[http https].include?(uri.scheme)
            key = uri.path.delete_prefix("/").delete_suffix("/").delete_suffix(".md").gsub("/", "--")
            link["href"] = if uri.host == base.host && Catalog.resource(key)
              Rails.application.routes.url_helpers.learning_resource_path(key, anchor: uri.fragment)
            else
              uri.to_s
            end
          else
            link.remove_attribute("href")
          end
        rescue URI::InvalidURIError
          link.remove_attribute("href")
        end
      end
      ApplicationController.helpers.sanitize(fragment.to_html, tags: TAGS, attributes: %w[href title id class])
    end
  end
end

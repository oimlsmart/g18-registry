# frozen_string_literal: true

require "erb"
require "fileutils"
require "cgi"
require "json"

module G18
  module Site
    # Renders the static site from a loaded Dataset using ERB templates.
    # Templates live in `templates/`; static assets in `static/`. Output
    # goes to `_site/`.
    class Renderer
      attr_reader :dataset, :templates_dir, :static_dir, :output_dir

      def initialize(dataset:, templates_dir:, static_dir:, output_dir:)
        @dataset = dataset
        @templates_dir = templates_dir
        @static_dir = static_dir
        @output_dir = output_dir
      end

      def render_all
        FileUtils.rm_rf(output_dir)
        FileUtils.mkdir_p(output_dir)
        copy_static
        page("index.html", "index")
        page("terms/index.html", "terms_index")
        dataset.terms.each { |t| page("terms/#{t.slug}.html", "term", term: t) }
        page("tc/index.html", "tc_index")
        dataset.tcscs.each { |tc| page("tc/#{tc.slug}.html", "tc", tc: tc) }
        page("publications/index.html", "publications_index")
        dataset.publications.each { |p| page("publications/#{p.slug}.html", "publication", pub: p) }
        page("leaderboard.html", "leaderboard")
        write_raw("stats.json", stats_json)
      end

      def copy_static
        return unless Dir.exist?(static_dir)
        Dir.children(static_dir).each do |child|
          src = File.join(static_dir, child)
          FileUtils.cp_r(src, output_dir)
        end
      end

      def page(output_path, template_name, **locals)
        body = render_partial(template_name, locals, output_path)
        html = render_layout(body, template_name, locals, output_path)
        write_page(output_path, html)
      end

      def write_page(rel_path, html)
        path = File.join(output_dir, rel_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, html)
      end

      def write_raw(rel_path, content)
        path = File.join(output_dir, rel_path)
        FileUtils.mkdir_p(File.dirname(path))
        File.write(path, content)
      end

      # Context is the binding `self` for ERB templates. Each template local
      # becomes a reader method on the context; helpers delegate to the
      # renderer. We use a binding (not result_with_hash) so templates can
      # call helper methods like `h(x)` and `kind_badge(t)` directly.
      class Context
        def initialize(renderer, locals)
          @renderer = renderer
          locals.each { |k, v| instance_variable_set(:"@#{k}", v) }
          locals.each_key do |k|
            next if respond_to?(k)
            define_singleton_method(k) { instance_variable_get(:"@#{k}") }
          end
        end

        def get_binding
          binding
        end

        def h(s) = @renderer.html_escape(s)
        def kind_badge(t) = @renderer.kind_badge(t)
        def consistency_badge_class(v) = @renderer.consistency_badge_class(v)
      end

      def render_partial(name, locals, output_path)
        template = ERB.new(File.read(File.join(templates_dir, "#{name}.html.erb")), trim_mode: "-")
        ctx = Context.new(self, locals.merge(rel_root: relative_root(output_path), dataset: dataset))
        template.result(ctx.get_binding)
      end

      def render_layout(body, current_page, locals, output_path)
        template = ERB.new(File.read(File.join(templates_dir, "_layout.html.erb")), trim_mode: "-")
        ctx = Context.new(self, locals.merge(
          body: body,
          current_page: current_page,
          rel_root: relative_root(output_path),
          dataset: dataset,
          site_title: "G 18 — OIML Term-Usage Registry",
        ))
        template.result(ctx.get_binding)
      end

      def stats_json
        {
          term_count: dataset.term_count,
          publication_count: dataset.publication_count,
          instance_count: dataset.instance_count,
          defined_term_count: dataset.defined_term_count,
          divergent_term_count: dataset.divergent_term_count,
          attributed_publication_count: dataset.attributed_publication_count,
        }.to_json
      end

      def html_escape(s)
        CGI.escapeHTML(s.to_s)
      end

      def consistency_badge_class(value)
        case value.to_s
        when "ok"      then "badge badge-ok"
        when "partial" then "badge badge-partial"
        when "ko"      then "badge badge-ko"
        when "pending" then "badge badge-pending"
        else "badge"
        end
      end

      def kind_badge(term)
        %(<span class="kind kind-#{html_escape term.kind}">#{html_escape term.vocabulary_label}</span>)
      end

      def relative_root(page_path)
        depth = page_path.to_s.split("/").size - 1
        "../" * [depth, 0].max
      end
    end
  end
end


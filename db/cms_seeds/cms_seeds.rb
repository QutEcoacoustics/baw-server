# frozen_string_literal: true

# assumes the rails application has been loaded!

# real host defined in CMS initializer in hostname_aliases setting
CMS_DEFAULT_SITE = 'default' unless defined? CMS_DEFAULT_SITE
cms_site = Comfy::Cms::Site.where(identifier: CMS_DEFAULT_SITE).first
cms_site = Comfy::Cms::Site.create!(identifier: CMS_DEFAULT_SITE, hostname: 'localhost') if cms_site.nil?

# check if layout is defined
layout = Comfy::Cms::Layout.where(identifier: 'default').first
if layout.nil?
  unless defined? CMS_LAYOUT_CONTENT
    CMS_LAYOUT_CONTENT = <<~HTML
      {{ cms:asset default, type: css, as: tag }}
      {{ cms:file header_image, as: image }}
      <h1>{{ cms:text title }}</h1>
      {{ cms:markdown content }}

      {{ cms:asset default, type: js, as: tag }}
    HTML
  end
  layout = Comfy::Cms::Layout.create!(
    site: cms_site,
    parent: nil,
    app_layout: '',
    label: 'Default layout',
    identifier: 'default',
    content: CMS_LAYOUT_CONTENT,
    css: '',
    js: '',
    position: 0
  )
end

# category
default_categories = ['default_pages'].map { |label|
  cms_site
    .categories
    .find_or_create_by(label: label, categorized_type: Comfy::Cms::Page.to_s)
}

def create_cms_seed_pages(layout, default_categories)
  {
    index: {
      layout: layout,
      label: 'Home',
      slug: 'index',
      full_path: '/',
      is_published: true,
      categories: default_categories,
      fragments_attributes: [
        { identifier: 'title', tag: 'text', content: '' },
        { identifier: 'content', tag: 'markdown', content: <<~MARKDOWN
          Welcome! This is an Acoustic Workbench website. It is a repository of
          environmental audio recordings.
        MARKDOWN
        }
      ]
    },
    credits: {
      layout: layout,
      label: 'Credits',
      slug: 'credits',
      full_path: '/credits',
      is_published: true,
      categories: default_categories,
      fragments_attributes: [
        { identifier: 'title', tag: 'text', content: '{{ cms:helper cms_page_label }}' },
        { identifier: 'content', tag: 'markdown', content: <<~MARKDOWN
          The development of this web application was an initiative of the
          [Queensland University of Technology's](https://www.qut.edu.au/)
          [Ecoacoustics Research Group](http://research.ecosounds.org/).
          This website makes use of a range of other technologies and libraries.


          More information can be found on the
          [QutEcoacoustics](https://github.com/QutEcoacoustics) Github project page.

          ## Programs and libraries

          - [Ruby on Rails](http://rubyonrails.org/) (with a number of additional gems)
          - [Resque](https://github.com/resque/resque)
          - [Redis](http://redis.io)
          - Command line audio tools:
          - [ffmpeg](http://www.ffmpeg.org/) (for audio conversion and gathering audio file information)
          - [SoX](http://sox.sourceforge.net/) (to create spectrograms and resample audio)
          - [WavPack](http://www.wavpack.com/) (to expand compressed .wv files)
          - [mp3split](http://mp3splt.sourceforge.net/mp3splt_page/home.php) (for quickly segmenting large .mp3 files)
          - [AngularJS](https://angularjs.org/)
          - [D3.js](https://d3js.org/)

          ## Platforms and services

          - [Github](https://github.com)
          - [QRISCloud](https://www.qriscloud.org.au/)
          - [nectar](https://https://nectar.org.au/)
        MARKDOWN
        }
      ]
    },
    data_upload: {
      layout: layout,
      label: 'Data Upload',
      slug: 'data_upload',
      full_path: '/data_upload',
      is_published: true,
      categories: default_categories,
      fragments_attributes: [
        { identifier: 'title', tag: 'text', content: '{{ cms:helper cms_page_label }}' },
        { identifier: 'content', tag: 'markdown', content: <<~MARKDOWN
          No instructions are available.
        MARKDOWN
        }
      ]
    },
    ethics: {
      layout: layout,
      label: 'Ethics',
      slug: 'ethics',
      full_path: '/ethics',
      is_published: true,
      categories: default_categories,
      fragments_attributes: [
        { identifier: 'title', tag: 'text', content: '{{ cms:helper cms_page_label }}' },
        { identifier: 'content', tag: 'markdown', content: <<~MARKDOWN
          No ethics statement available for this project.
        MARKDOWN
        }
      ]
    },
    privacy: {
      layout: layout,
      label: 'Privacy',
      slug: 'privacy',
      full_path: '/privacy',
      is_published: true,
      categories: default_categories,
      fragments_attributes: [
        { identifier: 'title', tag: 'text', content: '{{ cms:helper cms_page_label }}' },
        { identifier: 'content', tag: 'markdown', content: <<~MARKDOWN
          We make no representations about the suitability of this information for any
          purpose. It is provided "as is" without express or implied warranty.

          We disclaim all warranties with regard to this information, including all
          implied warranties of merchantability and fitness. In no event shall we be
          liable for any special, indirect or consequential damages or any damages whatsoever
          resulting from loss of use, data or profits, whether in an action of contract,
          negligence or other tortious action,
          arising out of or in connection with the use or performance of this information.

          This information may include technical inaccuracies or typographical errors.

          We may make improvements or changes to the information and data at any time.
        MARKDOWN
        }
      ]
    }

  }
end

cms_seed_pages = create_cms_seed_pages(layout, default_categories)

def create_page(site, hash, parent = nil)
  slug = hash[:slug].split('/').last
  page = site.pages.where(slug: slug).first
  if page.nil?
    page = Comfy::Cms::Page.new(**hash)
    page.parent = parent
    page.site = site
    page.save!
  end

  page
end

index = create_page(cms_site, cms_seed_pages[:index])

cms_seed_pages.except(:index).each do |_key, page_hash|
  create_page(cms_site, page_hash, index)
end

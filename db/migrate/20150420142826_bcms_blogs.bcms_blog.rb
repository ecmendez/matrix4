# This migration comes from bcms_blog (originally 20090415000000)
require 'pp'

Cms::Page # trigger auto-loading
# At the time of this writing, these associations are missing :dependent => :destroy
class Cms::Page
  has_many :page_routes, :dependent => :destroy
end
class Cms::PageRoute
  has_many :requirements, :class_name => "PageRouteRequirement", :dependent => :destroy
  has_many :conditions,   :class_name => "PageRouteCondition",   :dependent => :destroy
end

class BcmsBlogs < ActiveRecord::Migration
  def self.up
    create_content_table :blogs, :force => true do |t|
      t.string :name
      t.string :format
      t.text :template
      t.boolean :moderate_comments, :default => true
    end


    create_table :blog_group_memberships do |t|
      t.integer :blog_id
      t.integer :group_id
    end

    create_content_table :blog_posts do |t|
      t.integer :blog_id
      t.integer :author_id
      t.integer :category_id
      t.string :name
      t.string :slug
      t.text :summary
      t.text :body, :size => (64.kilobytes + 1)
      t.integer :comments_count
      t.datetime :published_at
      t.belongs_to :attachment
      t.integer :attachment_version
    end

    create_content_table :blog_comments do |t|
      t.integer :post_id
      t.string :author
      t.string :email
      t.string :url
      t.string :ip
      t.text :body
    end

    apply_cms_namespace_to_all_core_tables

    INDEXES.each do |index|
      table_name, column = *index
      add_index cms_(table_name), column
    end
  end

  def self.down
    puts "Destroying portlets, pages, page_routes..."
    pp (portlets = BlogPostPortlet.all).map(&:connected_pages).flatten.each(&:destroy)
    pp portlets.each(&:destroy)

    #Blog.all.map(&:connected_pages).flatten.map(&:page_routes).flatten.each(&:destroy)
    pp BcmsBlog::Blog.all.map(&:connected_pages).flatten.each(&:destroy)

    # Cms::ContentType.destroy_all(name: "Blog")
    # Cms::Connector.destroy_all(connectable_type: "Blog")

    drop_table :cms_blogs
    drop_table :cms_blog_versions
    drop_table :cms_blog_group_memberships
    drop_table :cms_blog_posts
    drop_table :cms_blog_post_versions
    drop_table :cms_blog_comments
    drop_table :cms_blog_comment_versions
  end

  private

  def apply_cms_namespace_to_all_core_tables
    unversioned_tables.each do |table_name|
      if (needs_namespacing(table_name))
        rename_table table_name, cms_(table_name)
      end
    end

    versioned_tables.each do |table_name|
      if (needs_namespacing(table_name))
        rename_table table_name, cms_(table_name)
        rename_table versioned_(table_name), cms_(versioned_(table_name))
      end
    end
  end

  def versioned_tables
    [:blogs, :blog_comments, :blog_posts]
  end

  def unversioned_tables
    [:blog_group_memberships]
  end

  def needs_namespacing(table_name)
    table_exists?(table_name) && !table_exists?(cms_(table_name))
  end

  def versioned_(table_name)
    "#{table_name.to_s.singularize}_versions".to_sym
  end

  # Add some very commonly used indexes to improve the site performance as the # of pages/content grows (i.e. several thousand pages)
  INDEXES = [
      [:blogs, :version],
      [:blog_posts, :version],
      [:blog_comments, :version],
      [:blog_versions, :original_record_id],
      [:blog_post_versions, :original_record_id],
      [:blog_comment_versions, :original_record_id]
  ]
end

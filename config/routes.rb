Rails.application.routes.draw do
  mount_bcms_blog
  mount_browsercms

  namespace :bcms_blog do
    content_blocks :blogs
    content_blocks :blog_posts
    content_blocks :blog_comments
  end
end

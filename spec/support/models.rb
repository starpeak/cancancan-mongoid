class MongoidCategory
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic if Mongoid::VERSION >= '4.0'

  has_many :mongoid_projects
end

class MongoidProject
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic if Mongoid::VERSION >= '4.0'

  if Mongoid::VERSION >= '6.2.0'
    belongs_to :mongoid_category, required: false
  elsif Mongoid::VERSION >= '6.0.0'
    belongs_to :mongoid_category, optional: true
  else
    belongs_to :mongoid_category
  end
  has_many :mongoid_sub_projects
end

class MongoidSubProject
  include Mongoid::Document
  include Mongoid::Attributes::Dynamic if Mongoid::VERSION >= '4.0'

  if Mongoid::VERSION >= '6.2.0'
    belongs_to :mongoid_project, required: false
  elsif Mongoid::VERSION >= '6.0.0'
    belongs_to :mongoid_project, optional: true
  else
    belongs_to :mongoid_project
  end
end

class MongoidPost
  include Mongoid::Document

  embeds_many :mongoid_comments
  embeds_many :tags, class_name: 'MongoidPostTag'
end

class MongoidComment
  include Mongoid::Document

  field :name

  embedded_in :mongoid_post
end

class MongoidPostTag
  include Mongoid::Document

  field :key
  field :name

  embedded_in :mongoid_post
end
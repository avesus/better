# Redmine - project management software
# Copyright (C) 2006-2009  Shereef Bishay
#

class GroupCustomField < CustomField
  def type_name
    :label_group_plural
  end
end


# == Schema Information
#
# Table name: custom_fields
#
#  id              :integer         not null, primary key
#  type            :string(30)      default(""), not null
#  name            :string(30)      default(""), not null
#  field_format    :string(30)      default(""), not null
#  possible_values :text
#  regexp          :string(255)     default("")
#  min_length      :integer         default(0), not null
#  max_length      :integer         default(0), not null
#  is_required     :boolean         default(FALSE), not null
#  is_for_all      :boolean         default(FALSE), not null
#  is_filter       :boolean         default(FALSE), not null
#  position        :integer         default(1)
#  searchable      :boolean         default(FALSE)
#  default_value   :text
#  editable        :boolean         default(TRUE)
#

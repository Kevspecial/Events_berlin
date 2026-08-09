require 'test_helper'

class CategoryTest < ActiveSupport::TestCase
  test 'valid category' do
    category = Category.new(name: 'Jazz')
    assert category.valid?
  end

  test 'requires name' do
    category = Category.new
    assert_not category.valid?
    assert_includes category.errors[:name], "can't be blank"
  end

  test 'requires unique name' do
    Category.create!(name: 'Jazz')
    category = Category.new(name: 'Jazz')
    assert_not category.valid?
    assert_includes category.errors[:name], 'has already been taken'
  end
end

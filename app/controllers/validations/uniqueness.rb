class Uniqueness < ActiveModel::EachValidator
  # Given the following call:
  #
  #     validates :uid, uniqueness: { scope: :provider } # in class User
  #
  # `attribute` is :uid, `value` is the User's uid, `record` is the User instance.
  def validate_each(record, attribute, value)
    filter = { attribute => value }
    filter.merge!({ options[:scope] => record.send(options[:scope]) }) if options[:scope]
    existing_users = User.where(filter)
    # Has it been saved yet? If so there should be at most 1, otherwise at most 0 (since it'll save if valid).
    return unless existing_users.size > (record.new_record? ? 0 : 1)

    # E.g., "has already been taken for provider 'google_oauth2'"
    record.errors.add(attribute, "has already been taken for #{attribute} '#{value}'")
  end
end

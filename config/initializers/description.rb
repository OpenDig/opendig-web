require 'json'

descriptions = Rails.root.join('config', 'descriptions.json')

Rails.application.config.descriptions = JSON.parse descriptions.read

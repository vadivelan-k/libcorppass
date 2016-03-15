require 'active_support/concern'

module CorpPass
  module Notification
    extend ActiveSupport::Concern

    def notify(event, payload)
      self.class.notify(event, payload)
    end

    class_methods do
      def notify(event, payload)
        class_name = name.demodulize.underscore
        ActiveSupport::Notifications.instrument "corp_pass.#{class_name}.#{event}", payload
        payload
      end
    end
  end
end

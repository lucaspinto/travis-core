require 'core_ext/module/include'
require 'pusher'

module Travis
  module Notifications
    module Handler

      # Notifies registered clients about various state changes through Pusher.
      class Pusher
        autoload :Payload, 'travis/notifications/handler/pusher/payload'

        EVENTS = [/build:(started|finished)/, /job:test:(created|started|log|finished)/, /worker:.*/]

        include Logging

        include do
          def notify(event, object, *args)
            push(event, object, *args)
          end

          protected

            def push(event, object, *args)
              data  = args.last.is_a?(Hash) ? args.pop : {}
              data  = payload_for(event, object, data)
              event = client_event_for(event)
              channel(event, object).trigger(event, data)
            end

            def config
              @config ||= Travis.config.pusher
            end

            def pusher
              @pusher ||= ::Pusher.tap do |pusher|
                pusher.app_id = config.app_id
                pusher.key    = config.key
                pusher.secret = config.secret
              end
            end

            def channel(event, object)
              pusher[queue_for(event, object)]
            end

            def client_event_for(event)
              case event
              when /job:.*/
                event.gsub(/(test|configure):/, '')
              else
                event
              end
            end

            def queue_for(event, object)
              case event
              when 'job:log'
                "job-#{object.id}"
              else
                'common'
              end
            end

            def payload_for(event, object, extra = {})
              Payload.new(client_event_for(event), object, extra).to_hash
            end
        end
      end
    end
  end
end

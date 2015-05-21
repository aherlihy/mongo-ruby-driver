# Copyright (C) 2015 MongoDB, Inc.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Mongo
  module Monitoring

    # Defines behaviour for an object that can publish monitoring events.
    #
    # @since 2.1.0
    module Publishable

      # Publish a command event to the global monitoring.
      #
      # @example Publish a command event.
      #   publish_command do |messages|
      #     # ...
      #   end
      #
      # @param [ Array<Message> ] messages The messages.
      #
      # @return [ Object ] The result of the yield.
      #
      # @since 2.1.0
      def publish_command(messages)
        if monitoring?
          start = Time.now
          payload = messages.first.payload
          Monitoring.started(Monitoring::COMMAND, command_started(payload))
        end
        begin
          result = yield(messages)
          if monitoring?
            Monitoring.completed(
              Monitoring::COMMAND,
              command_completed(payload, result ? result.payload : nil, start)
            )
          end
          result
        rescue Exception => e
          if monitoring?
            Monitoring.failed(Monitoring::COMMAND, command_failed(payload, e, start))
          end
          raise e
        end
      end

      private

      def command_started(payload)
        Event::CommandStarted.new(
          payload[:name],
          payload[:database],
          address.to_s,
          payload[:arguments]
        )
      end

      def command_completed(started_payload, completed_payload, start)
        Event::CommandCompleted.new(
          started_payload[:name],
          started_payload[:database],
          address.to_s,
          completed_payload ? completed_payload[:reply] : nil,
          duration(start)
        )
      end

      def command_failed(started_payload, exception, start)
        Event::CommandFailed.new(
          started_payload[:name],
          started_payload[:database],
          address.to_s,
          exception.message,
          duration(start)
        )
      end

      def duration(start)
        Time.now - start
      end

      def monitoring?
        options[:monitor] != false
      end
    end
  end
end
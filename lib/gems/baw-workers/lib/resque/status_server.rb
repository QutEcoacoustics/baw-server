# frozen_string_literal: true

#require 'resque/server'

  module Resque
    module StatusServer
      VIEW_PATH = File.join(__dir__, 'server', 'views')
      PER_PAGE = 50

      # @return [BawWorkers::ActiveJob::Status::Persistance]
      def persistance
        @persistance ||= BawWorkers::ActiveJob::Status::Persistance
      end


      def self.registered(app)


        app.get '/statuses' do
          @start = params[:start].to_i
          @end = @start + (params[:per_page] || per_page) - 1
          @statuses = persistance.statuses(@start, @end)
          @size = persistance.count
          status_view(:statuses)
        end

        app.get '/statuses/:id.js' do
          @status = persistance.get(params[:id])
          content_type :js
          @status.json
        end

        app.get '/statuses/:id' do
          @status = persistance.get(params[:id])
          status_view(:status)
        end

        app.post '/statuses/:id/kill' do
          persistance.kill(params[:id])
          redirect u(:statuses)
        end

        app.post '/statuses/clear' do
          persistance.clear
          redirect u(:statuses)
        end

        app.post '/statuses/clear/completed' do
          persistance.clear_completed
          redirect u(:statuses)
        end

        app.post '/statuses/clear/failed' do
          persistance.clear_failed
          redirect u(:statuses)
        end

        app.get '/statuses.poll' do
          content_type 'text/plain'
          @polling = true

          @start = params[:start].to_i
          @end = @start + (params[:per_page] || per_page) - 1
          @statuses = persistance.statuses(@start, @end)
          @size = persistance.count
          status_view(:statuses, { layout: false })
        end

        app.helpers do
          def per_page
            PER_PAGE
          end

          def status_view(filename, options = {}, locals = {})
            erb(File.read(File.join(::Resque::StatusServer::VIEW_PATH, "#{filename}.erb")), options, locals)
          end

          def status_poll(start)
            text = if @polling
                    "Last Updated: #{Time.now.strftime('%H:%M:%S')}"
                  else
                    "<a href='#{u(request.path_info)}.poll?start=#{start}' rel='poll'>Live Poll</a>"
                  end
            "<p class='poll'>#{text}</p>"
          end
        end

        app.tabs << 'Statuses'
      end
    end
  end


::Resque::Server.register Resque::StatusServer

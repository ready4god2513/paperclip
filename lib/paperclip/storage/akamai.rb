module Paperclip
  module Storage
    
    module Akamai
      
      def self.extended base
        begin
          require 'akamaized'
        rescue LoadError => e
          e.message << " (You may need to install the akamaized gem)"
          raise e
        end unless defined?(Akamaized::Connection)

        base.instance_eval do
          @akamai_options = parse_credentials(@options[:akamai_credentials])
          @akamaized = Akamaized::Connection.new(@akamai_options)
        end
        
        Paperclip.interpolates(:akamai_url) do |attachment, style|
          "http://#{@akamai_options[:public_url]}/#{attachment.path(style).gsub(%r{^/}, "")}"
        end
      end

      def parse_credentials creds
        creds = find_credentials(creds).stringify_keys
        (creds[Rails.env] || creds).symbolize_keys
      end

      def exists?(style = default_style)
        original_filename ? @akamaized.exists?(path(style)) : false
      end

      # Returns representation of the data of the file assigned to the given
      # style, in the format most representative of the current storage.
      def to_file style = default_style
      end

      def flush_writes #:nodoc:
        @queued_for_write.each do |style, file|
          begin
            log("saving #{path(style)}")
            @akamaized.put(file)
          rescue Exception => e
            raise
          end
        end
        @queued_for_write = {}
      end

      def flush_deletes #:nodoc:
        @queued_for_delete.each do |path|
          
          begin
            log("deleting #{path}")
            @akamaized.delete!(path)
          rescue Exception => e
            raise
          end
          
        end
        
        @queued_for_delete = []
      end

      def find_credentials creds
        case creds
        when File
          YAML::load(ERB.new(File.read(creds.path)).result)
        when String, Pathname
          YAML::load(ERB.new(File.read(creds)).result)
        when Hash
          creds
        else
          raise ArgumentError, "Credentials are not a path, file, or hash."
        end
      end
      private :find_credentials

    end
  end
end

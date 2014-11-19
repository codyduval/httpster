class Httpster
  require 'socket'
  require 'uri'
  require 'pry'

  WEB_ROOT = './public'

  CONTENT_TYPE_MAPPING = {
    'html' => 'text/html',
    'htm' => 'text/html',
    'txt' => 'text/plain',
    'png' => 'image/png',
    'jpg' => 'image/jpeg'
   }

  DEFAULT_CONTENT_TYPE = 'application/octet-stream'

  def initialize(port=2000)
    @port = port
    @server = TCPServer.open(port)
  end

  def verb_and_header(socket)
    request = ""
    headers = {}
    while (request_line = socket.gets and request_line != "\r\n")
      request += request_line
    end

    header_params = request.split(/\r?\n/)
    first_line = header_params.shift.split(" ")
    verb = first_line[0]
    request_uri = first_line[1]
    header_params.each do |param|
      key_value = param.split(':')
      headers.merge!(key_value[0] => key_value[1].strip)
    end
    {:verb => verb, :request_uri => request_uri, :headers => headers}
  end

  def body(socket, content_length)
    socket.readpartial(content_length)  
  end

  def run
    puts "Connecting on port #{@port}"

    loop do
      socket = @server.accept
      request = verb_and_header(socket)
      STDERR.puts request 

      http_verb = request[:verb]
      request_uri = request[:request_uri]
      headers = request[:headers]

      if headers.has_key? 'Content-Length'
        http_body = body(socket, headers['Content-Length'].to_i)
        headers['Body'] = http_body
        STDERR.puts http_body 
      end

      if http_verb == 'GET'
        get(request_uri, socket)
      elsif http_verb == 'POST'
        #post(request, socket)
      elsif http_verb == 'PUT'
        #put(request, socket)
      elsif http_verb == 'DELETE'
        #delete(request, socket)
      elsif http_verb == 'HEAD'
        #head(request, socket)
      end
    end
  end

  private
  
  def head(request_line, socket)
    path = requested_file(request_line) if request_line 

    if File.directory?(path)
      path = File.join(path, 'index.html')
    end

    # Make sure the file exists and is not a directory
    # before attempting to open it.
    if File.exist?(path) && !File.directory?(path)
      File.open(path, "rb") do |file|
        socket.print "HTTP/1.1 200 OK\r\n" +
                     "Content-Type: #{content_type(file)}\r\n" +
                     "Content-Length: #{file.size}\r\n" +
                     "Connection: close\r\n"

        socket.print "\r\n"
      end
    else
      message = "File not found\n"

      # respond with a 404 error code to indicate the file does not exist
      socket.print "HTTP/1.1 404 Not Found\r\n" +
                   "Content-Type: text/plain\r\n" +
                   "Content-Length: #{message.size}\r\n" +
                   "Connection: close\r\n"

      socket.print "\r\n"

      socket.print message
    end
  end

  def post(request, socket)
    socket.print "HTTP/1.1 200 OK\r\n" +
                 "Content-Type: #{content_type(file)}\r\n" +
                 "Content-Length: #{file.size}\r\n" +
                 "Connection: close\r\n"

    socket.print "\r\n"
  end

  def get(request_uri, socket)
    path = requested_file(request_uri) 

    if File.directory?(path)
      path = File.join(path, 'index.html')
    end

    # Make sure the file exists and is not a directory
    # before attempting to open it.
    if File.exist?(path) && !File.directory?(path)
      File.open(path, "rb") do |file|
        socket.print "HTTP/1.1 200 OK\r\n" +
                     "Content-Type: #{content_type(file)}\r\n" +
                     "Content-Length: #{file.size}\r\n" +
                     "Connection: close\r\n"

        socket.print "\r\n"

        # write the contents of the file to the socket
        IO.copy_stream(file, socket)
      end
    else
      message = "File not found\n"

      # respond with a 404 error code to indicate the file does not exist
      socket.print "HTTP/1.1 404 Not Found\r\n" +
                   "Content-Type: text/plain\r\n" +
                   "Content-Length: #{message.size}\r\n" +
                   "Connection: close\r\n"

      socket.print "\r\n"

      socket.print message
    end
  end

  def content_type(path)
    ext = File.extname(path).split(".").last
    CONTENT_TYPE_MAPPING.fetch(ext, DEFAULT_CONTENT_TYPE)
  end

  #Borrowed from rack 'cause its safe
  def requested_file(request_uri)
    path = URI.unescape(URI(request_uri).path)

    clean = []

    # Split the path into components
    parts = path.split("/")

    parts.each do |part|
      # skip any empty or current directory (".") path components
      next if part.empty? || part == '.'
      # If the path component goes up one directory level (".."),
      # remove the last clean component.
      # Otherwise, add the component to the Array of clean components
      part == '..' ? clean.pop : clean << part
    end

    # return the web root joined to the clean path
    File.join(WEB_ROOT, *clean)
  end
end
 

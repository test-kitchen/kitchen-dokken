module DokkenHelpers
  # Create container if missing
  #
  # @param name [String]
  # @param args [Hash]
  # @return [Docker::Container]
  # def create_if_missing(name, args)
  def create_if_missing(args)
    # test
    begin
      c = Docker::Container.get(args['name'])
      return c
    rescue Docker::Error::NotFoundError
      puts "creating container #{args['name']}"
    end

    Docker::Container.create(args)
  end

  def run_if_missing(args)
    begin
      # require 'pry'; binding.pry
      c = Docker::Container.get(args['name'])
    rescue Docker::Error::NotFoundError
      # require 'pry'; binding.pry
      c = create_if_missing(args)
      c.start
      return c
    end
  end

  def destroy_if_running(name)
    c = Docker::Container.get(name)
    puts "destroying container #{name}"

    c.stop
    c.remove
  rescue
    puts "container #{name} not found"
  end

  # Pull image from the Docker registry if missing
  def pull_if_missing(image, tag)
    # test
    @repotags = []
    Docker::Image.all.each { |i| @repotags << i.info['RepoTags'] }
    next if @repotags.include?(["#{image}:#{tag}"])
    
    # repair    
    Docker::Image.create('fromImage' => image, 'tag' => tag)
  end
end

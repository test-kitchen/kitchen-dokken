module DokkenHelpers
  # Create container if missing
  #
  # @param name [String]
  # @param args [Hash]
  # @return [Docker::Container]
  # def run_if_missing(name, args)
  def run_if_missing(args)
    # test
    begin
      container = Docker::Container.get(args['name'])
      return container
    rescue Docker::Error::NotFoundError
      puts "creating container #{args['name']}"
    end

    Docker::Container.create(args)
  end

  def destroy_if_running(name)
    container = Docker::Container.get(name)
    puts "destroying container #{name}"

    container.stop
    container.remove
  rescue
    puts "container #{name} not found"
  end

  # Pull image from the Docker registry if missing
  def pull_if_missing(image, tag)
    # test
    @repotags.each { |t| return if t.include?("#{image}:#{tag}") }
    # repair
    Docker::Image.create('fromImage' => image, 'tag' => tag)
  end
end

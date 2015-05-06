module DokkenHelpers
  # Create container if missing
  def run_if_missing(name, args)
    # test
    begin
      container = Docker::Container.get(name)
      return container
    rescue Docker::Error::NotFoundError
      puts "creating container #{name}"
    end

    # repair
    container = Docker::Container.create(args)
    container.rename(name)
    container
  end

  # Pull image from the Docker registry if missing
  def pull_if_missing(image,tag)
    # test
    @repotags.each { |t| return if t.include?("#{image}:#{tag}") }
    # repair
    Docker::Image.create('fromImage' => image, 'tag' => tag)
  end

  
end

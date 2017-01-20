require 'docker'
require_relative 'lib/kitchen/driver/dokken'

desc 'builds the data image locally'
task :create_data_image do
  data_image = ENV['DOKKEN_DATA_IMAGE'] || 'someara/kitchen-cache:latest'

  if ::Docker::Image.exist?(data_image)
    puts "===> image #{data_image} already exists. please remove and retry:"
    puts "     docker image rm #{data_image}"
    exit 1
  end

  puts "===> building image: #{data_image}"

  dokken = Kitchen::Driver::Dokken.new(
    data_image: data_image
  )

  image_name = dokken.create_data_image.first
  image = ::Docker::Image.get(image_name)

  puts "===> image #{data_image} created: #{image.id}"
end

task :default do
  system 'rake --tasks'
end

require 'xcodeproj'

project_path = 'GuideDogs.xcodeproj'
project = Xcodeproj::Project.open(project_path)

# Main target
target = project.targets.find { |t| t.name == 'Soundscape' }
test_target = project.targets.find { |t| t.name == 'SoundscapeTests' }

# Function to add a file to a group and target
def add_file_to_target(project, target, file_path, group_path)
  group = project.main_group
  group_path.split('/').each do |name|
    group = group.groups.find { |g| g.name == name || g.path == name } || group.new_group(name)
  end
  
  file_ref = group.files.find { |f| f.path == File.basename(file_path) }
  unless file_ref
    file_ref = group.new_file(file_path)
  end
  
  unless target.source_build_phase.files_references.include?(file_ref)
    target.add_file_references([file_ref])
  end
  puts "Added #{file_path} to #{target.name}"
end

add_file_to_target(project, target, 'Code/Devices/BLE/ESP32BeltBLEDevice.swift', 'Code/Devices/BLE')
add_file_to_target(project, target, 'Code/Devices/ESP32BeltDevice.swift', 'Code/Devices')
add_file_to_target(project, target, 'Code/Devices/BeltPacketEncoder.swift', 'Code/Devices')
add_file_to_target(project, target, 'Code/Sensors/BeltNavigationStreamManager.swift', 'Code/Sensors')

add_file_to_target(project, test_target, 'Tests/BeltPacketEncoderTests.swift', 'Tests')

project.save

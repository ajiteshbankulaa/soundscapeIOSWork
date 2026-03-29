require 'xcodeproj'

project_path = 'GuideDogs.xcodeproj'
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'Soundscape' }
test_target = project.targets.find { |t| t.name == 'SoundscapeTests' }

# remove existing bad ones
['Code/Devices/BLE/ESP32BeltBLEDevice.swift', 'Code/Devices/ESP32BeltDevice.swift', 'Code/Devices/BeltPacketEncoder.swift', 'Code/Sensors/BeltNavigationStreamManager.swift'].each do |bad_path|
  file = project.files.find { |f| f.path == bad_path }
  if file
    target.source_build_phase.remove_file_reference(file) if target
    file.remove_from_project
  end
end

['Tests/BeltPacketEncoderTests.swift'].each do |bad_path|
  file = project.files.find { |f| f.path == bad_path }
  if file && test_target
    test_target.source_build_phase.remove_file_reference(file)
    file.remove_from_project
  end
end

def add_file_to_target(project, target, file_path, group_path)
  group = project.main_group
  group_path.split('/').each do |name|
    group = group.groups.find { |g| g.name == name || g.path == name } || group.new_group(name)
  end
  
  file_ref = group.new_file(file_path)
  target.add_file_references([file_ref])
end

add_file_to_target(project, target, 'Code/Devices/BLE/ESP32BeltBLEDevice.swift', 'GuideDogs/Code/Devices/BLE')
add_file_to_target(project, target, 'Code/Devices/ESP32BeltDevice.swift', 'GuideDogs/Code/Devices')
add_file_to_target(project, target, 'Code/Devices/BeltPacketEncoder.swift', 'GuideDogs/Code/Devices')
add_file_to_target(project, target, 'Code/Sensors/BeltNavigationStreamManager.swift', 'GuideDogs/Code/Sensors')
add_file_to_target(project, test_target, 'Tests/BeltPacketEncoderTests.swift', 'GuideDogs/Tests') if test_target

project.save
puts "Successfully saved project!"

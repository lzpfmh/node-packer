# Copyright (c) 2016-2017 Minqi Pan
# 
# This file is part of Node.js Compiler, distributed under the MIT License
# For full terms see the included LICENSE file

require 'shellwords'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'open3'

module Node
  class Compiler
    module Utils
      class << self
        def run(*args)
          STDERR.puts "-> Running #{args}"
          pid = spawn(*args)
          pid, status = Process.wait2(pid)
          raise Error, "Failed running #{args}" unless status.success?
        end

        def chdir(path)
          STDERR.puts "-> cd #{path}"
          Dir.chdir(path) { yield }
          STDERR.puts "-> cd #{Dir.pwd}"
        end

        def prepare_tmpdir(tmpdir)
          STDERR.puts "-> FileUtils.mkdir_p(#{tmpdir})"
          FileUtils.mkdir_p(tmpdir)
          Dir[::Node::Compiler::VENDOR_DIR + '/*'].each do |dirpath|
            target = File.join(tmpdir, File.basename(dirpath))
            unless Dir.exist?(target)
              STDERR.puts "-> FileUtils.cp_r(#{dirpath}, #{target})"
              FileUtils.cp_r(dirpath, target)
            end
          end
        end

        def inject_memfs(source, target)
          copy_dir = File.expand_path("./lib#{MEMFS}", target)
          if File.exist?(copy_dir)
            STDERR.puts "-> FileUtils.remove_entry_secure(#{copy_dir})"
            FileUtils.remove_entry_secure(copy_dir)
          end
          STDERR.puts "-> FileUtils.cp_r(#{source}, #{copy_dir})"
          FileUtils.cp_r(source, copy_dir)
          manifest = File.expand_path('./enclose_io_manifest.txt', target)
          File.open(manifest, "w") do |f|
            Dir["#{copy_dir}/**/*"].each do |fullpath|
              next unless File.file?(fullpath)
              if 0 == File.size(fullpath) && Gem.win_platform?
                # Fix VC++ Error C2466
                # TODO: what about empty file semantics?
                File.open(fullpath, 'w') { |f| f.puts ' ' }
              end
              entry = "lib#{fullpath[(fullpath.index MEMFS)..-1]}"
              f.puts entry
            end
          end
          return copy_dir
        end
      end
    end
  end
end
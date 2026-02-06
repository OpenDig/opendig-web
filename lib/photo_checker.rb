module PhotoChecker
  class << self
    def run(file)
      File.open("data/#{file}.csv").each do |l|
        line = l.chomp.split(',', -1)
        reg_number = line[0]
        puts "Missing #{reg_number}" unless Find.check_image(reg_number)
      end
    end
  end
end

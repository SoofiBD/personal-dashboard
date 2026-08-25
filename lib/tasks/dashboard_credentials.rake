namespace :dashboard do
  namespace :credentials do
    desc "Interactively set or rotate the dashboard owner password"
    task set: :environment do
      require "io/console"

      password = ENV["DASHBOARD_AUTH_PASSWORD"].presence
      confirmation = password
      unless password
        print "Dashboard password: "
        password = $stdin.noecho(&:gets).to_s.chomp
        puts
        print "Confirm dashboard password: "
        confirmation = $stdin.noecho(&:gets).to_s.chomp
        puts
      end

      abort "DASHBOARD_AUTH_PASSWORD must be at least 16 characters" if password.length < 16
      abort "DASHBOARD_AUTH_PASSWORD must not exceed 72 bytes" if password.bytesize > 72
      abort "Dashboard password confirmation does not match" unless password == confirmation

      owner = User.dashboard_owner
      owner.rotate_dashboard_password!(password)
      puts "Dashboard owner password updated; existing sessions were revoked."
    end
  end
end

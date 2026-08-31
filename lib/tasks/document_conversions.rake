namespace :document_conversions do
  desc "Preview or permanently delete conversions older than the retention period"
  task :purge, [:days] => :environment do |_task, arguments|
    days = Integer(arguments[:days].presence || ENV.fetch("DOCUMENT_RETENTION_DAYS", "90"))
    abort "Retention süresi en az 1 gün olmalıdır." if days < 1

    scope = PersonalFinance::DocumentConversion.older_than(days.days.ago)
    count = scope.count
    unless ENV["CONFIRM"] == "yes"
      puts "Dry run: #{count} dönüşüm #{days} günden eski. Silmek için CONFIRM=yes ekleyin."
      next
    end

    scope.find_each(&:destroy!)
    puts "#{count} dönüşüm, kaynak PDF ve bağlı görseller silindi."
  rescue ArgumentError
    abort "Gün sayısı pozitif bir tam sayı olmalıdır."
  end
end

# "Bad" pails are pails numbered 900 or above — placeholders / junk that crept
# into the data. They live nested in loci docs (locus.pails[]).
#
# Two tasks, both scoped to one project + area + square:
#
#   # Read-only report + per-pail suggestion (DELETE empties, RENUMBER the rest):
#   RAILS_ENV=production bin/rails 'pails:audit[baluademo,25,61]'
#
#   # Apply the suggested fix — DRY RUN by default; set APPLY=1 to actually save:
#   RAILS_ENV=production bin/rails 'pails:fix[baluademo,25,61]'
#   RAILS_ENV=production APPLY=1 bin/rails 'pails:fix[baluademo,25,61]'
#
# Policy (matches the agreed default): a bad pail with NO finds and NO readings
# is DELETED; a bad pail that holds data is RENUMBERED to the next free number in
# the square (max existing good number + 1, incrementing). Review the audit first.
namespace :pails do
  # Pail numbers at or above this are "bad" (placeholders / junk).
  def bad_pail_threshold = 900

  # Some legacy docs store embedded collections as a Hash keyed by index instead
  # of an array; coerce both to an array of hashes.
  def embedded_rows(collection)
    rows = collection.is_a?(Hash) ? collection.values : collection
    Array(rows).select { |row| row.is_a?(Hash) }
  end

  # Gather, for one square: the bad pails (>= threshold) with their host doc, and
  # the set of "good" integer pail numbers already in use (to pick renumber
  # targets). Returns [bad, good_numbers].
  def scan_square(db, area, square)
    rows = db.view('opendig/loci', reduce: false,
                                   start_key: [area, square],
                                   end_key: [area, square, {}])['rows']
    ids = rows.map { |r| r['key'][3] }.compact.uniq

    bad = []
    good = []
    ids.each do |id|
      doc = begin
        db.get(id)
      rescue StandardError
        next
      end
      # Track each bad pail by its INDEX within the doc's pails: a single doc can
      # hold two pails with the SAME bad number (e.g. two 999s), so we must act
      # by position, not by number, or a delete/renumber would hit both.
      embedded_rows(doc['pails']).each_with_index do |pail, index|
        number = pail['pail_number'].to_s
        if number =~ /\A\d+\z/ && number.to_i >= bad_pail_threshold
          bad << { doc_id: id, code: doc['code'], index: index, pail: pail }
        elsif number =~ /\A\d+\z/
          good << number.to_i
        end
      end
    end

    # Stable order: by date, then current number.
    bad.sort_by! { |b| [b[:pail]['pail_date'].to_s, b[:pail]['pail_number'].to_i] }
    [bad, good]
  end

  def pail_summary(pail)
    finds = embedded_rows(pail['finds']).size
    readings = embedded_rows(pail['readings']).size
    "date=#{pail['pail_date'] || '—'}  finds=#{finds}  readings=#{readings}  " \
      "total=#{pail['total_count'].presence || '—'}  baskets=#{pail['baskets'].presence || '—'}"
  end

  # A pail is only truly empty (safe to delete) when it carries no excavation
  # data at all: no finds, no readings, AND no pottery counts/comments. A pail
  # with baskets/total/diagnostic counts is a real collection even with no finds
  # or readings entered yet, so it is renumbered rather than deleted.
  def empty_pail?(pail)
    embedded_rows(pail['finds']).empty? &&
      embedded_rows(pail['readings']).empty? &&
      pail['baskets'].to_s.strip.empty? &&
      pail['total_count'].to_s.strip.empty? &&
      pail['diagnostic_count'].to_s.strip.empty? &&
      pail['pottery_comments'].to_s.strip.empty?
  end

  desc 'Report pails numbered >= 900 in a square, with a suggested fix (read-only). e.g. pails:audit[baluademo,25,61]'
  task :audit, %i[project area square] => :environment do |_t, args|
    project = args[:project] || abort('Usage: pails:audit[project,area,square]')
    area = args[:area] || abort('Usage: pails:audit[project,area,square]')
    square = args[:square] || abort('Usage: pails:audit[project,area,square]')

    CouchDB.with_project(project) do
      db = CouchDB.main_db
      bad, good = scan_square(db, area, square)

      puts "Square #{area}.#{square} — #{bad.size} bad pail(s) (>= #{bad_pail_threshold}); " \
           "highest good pail number = #{good.max || 0}"
      if bad.empty?
        puts 'Nothing to do.'
        next
      end

      next_num = (good.max || 0) + 1
      bad.each do |entry|
        pail = entry[:pail]
        loc = "#{area}.#{square}.#{entry[:code]}"
        if empty_pail?(pail)
          suggestion = 'DELETE (empty)'
        else
          suggestion = "RENUMBER #{pail['pail_number']} -> #{next_num} (has data)"
          next_num += 1
        end
        puts "  locus #{loc}  pail #{pail['pail_number'].to_s.ljust(6)}  #{pail_summary(pail)}"
        puts "       => #{suggestion}"
      end
      puts "\nRun pails:fix[...] (APPLY=1 to write) to apply these suggestions."
    end
  end

  desc 'Apply the bad-pail fix (DELETE empties, RENUMBER the rest). DRY by default; APPLY=1 to save.'
  task :fix, %i[project area square] => :environment do |_t, args|
    project = args[:project] || abort('Usage: pails:fix[project,area,square]')
    area = args[:area] || abort('Usage: pails:fix[project,area,square]')
    square = args[:square] || abort('Usage: pails:fix[project,area,square]')
    apply = ENV['APPLY'].present?

    CouchDB.with_project(project) do
      db = CouchDB.main_db
      bad, good = scan_square(db, area, square)

      if bad.empty?
        puts "Square #{area}.#{square}: no bad pails. Nothing to do."
        next
      end

      # Plan renumber targets up front so they're stable across docs.
      next_num = (good.max || 0) + 1
      plan = bad.map do |entry|
        if empty_pail?(entry[:pail])
          entry.merge(action: :delete)
        else
          target = next_num
          next_num += 1
          entry.merge(action: :renumber, target: target)
        end
      end

      # Group by host doc so each doc is rewritten and saved once. Act by index
      # (not by number) so two same-numbered bad pails in one doc are handled
      # independently.
      deleted = 0
      renumbered = 0
      plan.group_by { |e| e[:doc_id] }.each do |doc_id, entries|
        doc = db.get(doc_id)
        pails = embedded_rows(doc['pails'])
        delete_idx = entries.select { |e| e[:action] == :delete }.map { |e| e[:index] }
        renumber_idx = entries.select { |e| e[:action] == :renumber }
                              .to_h { |e| [e[:index], e[:target]] }

        kept = []
        pails.each_with_index do |pail, index|
          next if delete_idx.include?(index)

          pail['pail_number'] = renumber_idx[index].to_s if renumber_idx[index]
          kept << pail
        end

        deleted += delete_idx.size
        renumbered += renumber_idx.size
        # Rewrite as a clean array (also heals any legacy Hash-shaped pails).
        doc['pails'] = kept
        db.save_doc(doc) if apply
        puts "  #{area}.#{square}.#{doc['code']}: deleted #{delete_idx.size}, renumbered #{renumber_idx.size}"
      end

      puts "\n#{apply ? 'APPLIED' : 'DRY RUN'} — deleted #{deleted}, renumbered #{renumbered} bad pail(s) in #{area}.#{square}." \
           "#{apply ? '' : ' Set APPLY=1 to write.'}"
    end
  end
end

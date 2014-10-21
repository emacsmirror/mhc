module Mhc
  module Sync
    ##
    # Sync Driver takes two calendar databases to sync.
    #
    # Each record in calendar has to respond to:
    # * Record#unmodified?
    # * Record#deleted?
    # * Record#etag
    # * Record#etag=
    # * Record#ex_etag
    #
    class Driver
      def initialize(db1, db2, strategy)
        @db1 = db1
        @db2 = db2
        @strategy = Strategy::Factory.create(strategy)
      end

      def sync_all(dry_run = false)
        uid_list.each do |uid|
          sync(uid, dry_run)
        end
      end

      private

      def sync(uid, dry_run = false, quiet = false)
        info1 = @db1.syncinfo(uid)
        info2 = @db2.syncinfo(uid)

        unless @strategy.whatnow(info1, info2) == :ignore or quiet
          STDERR.print "ABOUT#{dry_run ? '(DRY_RUN)' : ''} #{uid} => #{@strategy.whatnow(info1, info2)} "
          STDERR.print "(#{info1.sync_status} vs #{info2.sync_status})\n"
        end
        return @strategy.whatnow(info1, info2) if dry_run

        case @strategy.whatnow(info1, info2)
        when :ignore
          #ignore(side1, side2)
        when :conflict
          #merge(uid, @db1, @db2)
        when :delete_side1
          delete(uid, @db1, @db2)
        when :delete_side2
          delete(uid, @db2, @db1)
        when :side1_to_side2
          copy(uid, @db1, @db2)
        when :side2_to_side1
          copy(uid, @db2, @db1)
        when :ow_side1_to_side2
          copy(uid, @db1, @db2, :overwrite)
        when :ow_side2_to_side1
          copy(uid, @db2, @db1, :overwrite)
        end
      end

      def uid_list
        (@db1.uid_list + @db2.uid_list).sort.uniq
      end

      def merge(uid, db1, db2)
        # Not yet implemented
        s1 = db1.get(uid)
        s2 = db2.get(uid)
        STDERR.print("Conflict: UID=#{uid}, Summary=#{s1.summary} ... did nothing.\n")
      end


      def delete(uid, db, db2)
        info = db.syncinfo(uid)
        info2 = db2.syncinfo(uid)
        if db.delete(uid)
          info.mark_synced(nil)
          info2.mark_synced(nil)
        end
      end

      def copy(uid, db1, db2, overwrite = false)
        ev = db1.get(uid)
        STDERR.print "COPYING:#{overwrite ? ' (overwrite)' : ''} #{ev.uid}\n"

        db2.delete(uid) if overwrite

        if new_info = db2.put(ev, overwrite)
          db1.syncinfo(uid).mark_synced(ev.etag)
          db2.syncinfo(uid).mark_synced(new_info.etag)
        else
          STDERR.print "COPY: failed.\n"
        end
      end
    end # class Driver
  end # module  Sync
end # module Mhc

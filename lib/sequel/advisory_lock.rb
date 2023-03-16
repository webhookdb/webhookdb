# frozen_string_literal: true

require "sequel"

class Sequel::AdvisoryLock
  def initialize(db, key_or_key1, key2=nil, shared: false, xact: false)
    @db = db
    xstr = xact ? "_xact" : ""
    sharestr = shared ? "_shared" : ""
    @locker = to_expr("pg_advisory#{xstr}_lock#{sharestr}", key_or_key1, key2)
    @trylocker = to_expr("pg_try_advisory#{xstr}_lock#{sharestr}", key_or_key1, key2)
    @unlocker = to_expr(shared ? "pg_advisory_unlock_shared" : "pg_advisory_unlock", key_or_key1, key2)
    if key2
      @cond = {classid: key_or_key1, objid: key2, objsubid: 2}
    else
      k2 = key_or_key1 & 0xFFFF_FFFF
      @cond = {classid: 1, objid: k2, objsubid: 1}
    end
  end

  private def to_expr(name, key1, key2)
    return key2.nil? ? Sequel.function(name.to_sym, key1) : Sequel.function(name.to_sym, key1, key2)
  end

  def dataset(this: false)
    ds = @db[:pg_locks]
    ds = ds.where(@cond) if this
    return ds
  end

  # pg_advisory_lock
  # pg_advisory_lock_shared
  # pg_advisory_xact_lock
  # pg_advisory_xact_lock_shared
  def with_lock
    raise LocalJumpError unless block_given?
    @db.get(@locker)
    return yield
  ensure
    self.unlock
  end

  # pg_try_advisory_lock
  # pg_try_advisory_lock_shared
  # pg_try_advisory_xact_lock
  # pg_try_advisory_xact_lock_shared
  def with_lock?
    raise LocalJumpError unless block_given?
    acquired = @db.get(@trylocker)
    return false, nil unless acquired
    begin
      return true, yield
    ensure
      self.unlock
    end
  end

  def unlock
    @db.get(@unlocker)
  end

  def unlock_all
    @db.get(Sequel.function(:pg_advisory_unlock_all))
  end
end

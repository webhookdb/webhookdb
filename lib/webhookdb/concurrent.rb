# frozen_string_literal: true

module Webhookdb::Concurrent
  # Baseclass for pools for doing work across threads.
  # Note that these concurrent pools are not for repeated use,
  # like a normal threadpool. They are for 'fanning out' a single operation
  # across multiple threads.
  #
  # Tasks should not error; if they error, the pool will noop if more work is added via +post+,
  # and no new enqueued work will be processed.
  # The first error raised by a task is re-raised in +join+.
  class Pool
    # Add work to the pool.
    # Will not raise an error, but will block if no workers are free.
    # Noops if the pool has an error.
    def post(&) = raise NotImplementedError

    # Wait for all work to finish.
    # Re-raise the first exception for any pool error.
    def join = raise NotImplementedError
  end

  # Fake +Pool+ that does work in the calling thread,
  # but behaves like a threaded pool (ie, tasks do not raise).
  class SerialPool < Pool
    def post
      return if @exception
      yield
    rescue StandardError => e
      @exception = e
    end

    def join
      raise @exception if @exception
    end
  end

  # Pool that does work across a given number of threads.
  # +queue_size+ is how many items can be in the queue before +post+ blocks.
  # +threads+ defaults to +queue_size+, allowing at most +queue_size+ concurrent work,
  # which fits the idea of a parallelized pool well.
  #
  # If you want the calling thread to queue up a bunch of work ahead of time,
  # you can use a +Concurrent::ThreadPoolExecutor+. This pool will not allow the enqueing of more work
  # while the queue is full.
  class ParallelizedPool < Pool
    def initialize(queue_size, threads: nil)
      super()
      threads ||= queue_size
      @threads = (1..threads).map do
        Thread.new do
          loop { break unless self.do_work }
        end
      end
      @queue = Thread::SizedQueue.new(queue_size)
      @exception = nil
    end

    protected def do_work
      task = @queue.pop
      return false if task.nil?
      if task == STOP
        @queue.close
        return false
      end
      begin
        task.call
      rescue StandardError => e
        @exception ||= e
        return false
      end
      return true
    end

    def post(&task)
      return if @exception
      @queue.push(task)
    end

    def join
      @queue.push(STOP)
      @threads.each(&:join)
      raise @exception if @exception
    end

    STOP = :stop
  end
end

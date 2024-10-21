# frozen_string_literal: true

module Webhookdb::Concurrent
  class Timeout < Timeout::Error; end

  # Baseclass for pools for doing work across threads.
  # Note that these concurrent pools are not for repeated use,
  # like a normal threadpool. They are for 'fanning out' a single operation
  # across multiple threads.
  #
  # Tasks should not error; if they error, the pool will becomes inoperable:
  # +post+ and +join+ will re-raise the first task error.
  class Pool
    # Add work to the pool.
    # Will block if no workers are free.
    # Re-raises the pool's error if the pool has an error.
    # This is important as we don't want the caller to keep adding work,
    # if the pool is inoperable.
    def post(&) = raise NotImplementedError

    # Wait for all work to finish.
    # Re-raise the first exception for any pool error.
    def join = raise NotImplementedError
  end

  # Fake +Pool+ that does work in the calling thread,
  # but behaves like a threaded pool (ie, tasks do not raise).
  class SerialPool < Pool
    def post
      raise @exception if @exception
      begin
        yield
      rescue StandardError => e
        @exception = e
      end
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
    def initialize(queue_size, timeout: nil, threads: nil)
      super()
      threads ||= queue_size
      @timeout = timeout
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
      raise @exception if @exception
      added = @queue.push(task, timeout: @timeout)
      raise Timeout, "waited #{@timeout} to add to the queue" if added.nil?
      return true
    end

    def join
      @queue.push(STOP)
      @threads.each(&:join)
      raise @exception if @exception
    end

    STOP = :stop
  end
end

# frozen_string_literal: true

RSpec.describe "Webhookdb::BackfillJob", :db do
  let(:described_class) { Webhookdb::BackfillJob }

  it "can create cascading jobs for integrations without deps" do
    parent = Webhookdb::Fixtures.service_integration.create
    job = described_class.create_recursive(service_integration: parent, incremental: true)
    expect(job).to have_attributes(parent_job: nil, service_integration: be === parent, incremental: true)
  end

  it "can create cascading jobs for integrations with deep deps" do
    parent = Webhookdb::Fixtures.service_integration.create
    a = Webhookdb::Fixtures.service_integration(depends_on: parent).create
    b = Webhookdb::Fixtures.service_integration(depends_on: parent).create
    a_a = Webhookdb::Fixtures.service_integration(depends_on: a).create
    a_b = Webhookdb::Fixtures.service_integration(depends_on: a).create
    a_b_a = Webhookdb::Fixtures.service_integration(depends_on: a_b).create
    job = described_class.create_recursive(service_integration: parent, incremental: true)
    expect(job).to have_attributes(parent_job: nil, service_integration: be === parent, incremental: true)
    expect(job.child_jobs).to contain_exactly(
      have_attributes(service_integration: be === a, incremental: true),
      have_attributes(service_integration: be === b, incremental: true),
    )
  end

  it "can enqueue itself", :async, :do_not_defer_events do
    parent = Webhookdb::Fixtures.service_integration.create
    job = described_class.create(service_integration: parent, incremental: true)
    expect do
      job.enqueue
    end.to publish("webhookdb.backfilljob.run", [job.id])
  end

  it "can enqueue a single layer of children", :async, :do_not_defer_events do
    a = Webhookdb::Fixtures.service_integration.create
    a_a = Webhookdb::Fixtures.service_integration(depends_on: a).create
    a_a_a = Webhookdb::Fixtures.service_integration(depends_on: a_a).create
    job = described_class.create_recursive(service_integration: a, incremental: true)

    expect do
      job.enqueue_children
    end.to publish("webhookdb.backfilljob.run", [job.child_jobs[0].id])

    expect do
      job.child_jobs[0].enqueue_children
    end.to publish("webhookdb.backfilljob.run", [job.child_jobs[0].child_jobs[0].id])
  end

  it "is fully finished when all children and grandchildren are finished" do
    a = Webhookdb::Fixtures.service_integration.create
    a_a = Webhookdb::Fixtures.service_integration(depends_on: a).create
    a_a_a = Webhookdb::Fixtures.service_integration(depends_on: a_a).create
    job_a = Webhookdb::Fixtures.backfill_job.for(a).cascade.create
    job_aa = job_a.child_jobs.first
    job_aaa = job_aa.child_jobs.first

    t1 = Time.parse("2020-01-01")
    t2 = t1 + 1.day
    t3 = t2 + 1.day

    job_a.update(finished_at: t1)
    expect(job_a).to be_finished
    expect(job_a).to_not be_fully_finished

    # Mark the child, not grandchild, as finished latest, to make sure this time is used.
    # We should never see this, but still always want to use latest.
    job_aa.update(finished_at: t3)
    expect(job_a).to_not be_fully_finished

    job_aaa.update(finished_at: t2)
    expect(job_a).to be_fully_finished
    expect(job_a.fully_finished_at).to match_time(t3)

    expect(job_aa).to be_fully_finished
    expect(job_aa.fully_finished_at).to match_time(t3)

    expect(job_aaa).to be_fully_finished
    # Doesn't know about parent at t3, so uses t2
    expect(job_aaa.fully_finished_at).to match_time(t2)
  end

  it "can derive a status" do
    a = Webhookdb::Fixtures.service_integration.create
    a_a = Webhookdb::Fixtures.service_integration(depends_on: a).create

    job_a = Webhookdb::Fixtures.backfill_job.for(a).cascade.create
    job_aa = job_a.child_jobs.first

    expect(job_a).to have_attributes(status: "enqueued")
    job_a.started_at = Time.now
    expect(job_a).to have_attributes(status: "inprogress")
    job_a.finished_at = Time.now
    expect(job_a).to have_attributes(status: "inprogress")
    job_aa.finished_at = Time.now
    expect(job_a).to have_attributes(status: "finished")
  end
end

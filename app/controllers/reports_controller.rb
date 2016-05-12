class ReportsController < ApplicationController

  before_action :set_range

  def index
    @filter = params[:filter]
    @metric_id = params[:metric_id]

    @hosts = @application.hosts

    if @metric_id
      @transaction_metrics = @application.transaction_data.where(:id => @metric_id)
      @transaction_metric_samples = @application.transaction_data.where(:parent_id => @metric_id)
    elsif @filter
      @transaction_metrics = @application.transaction_data.where(:end_point => @filter)
    else
      @transaction_metrics = @application.transaction_data
        .group(:end_point)
        .where(:started_at => @range)
        .select("transaction_data.end_point, AVG(duration) AS duration")
    end
  end

  def show
    @filter = params[:filter]
    @report_data = []

    @metric_id = params[:metric_id]
    if @metric_id
      @transaction_metric = @application.transaction_data.where(:id => @metric_id).first
      @range = (@transaction_metric.started_at - 5.minutes)..(@transaction_metric.started_at + 5.minutes)
    end

    @plot_lines = [
      {
        color: 'red',
        dashStyle: "longdashdot",
        value: "2016-05-10 15:11:00 UTC",
        width: 2
      }
    ]

    case params[:id]
    when "average_duration"
      data = @application.event_data
      database_data = data.where(:name => "Database")
      ruby_data = data.where(:name => "Ruby")
      gc_data = data.where(:name => "GC Execution")

      @report_data.push({ :name => "Ruby", :data => ruby_data.group_by_minute(:timestamp, range: @range).calculate_all("SUM(value) / SUM(num)") }) if ruby_data.present?
      @report_data.push({ :name => "Database", :data => database_data.group_by_minute(:timestamp, range: @range).calculate_all("SUM(value) / SUM(num)") }) if database_data.present?
      @report_data.push({ :name => "GC Execution", :data => gc_data.group_by_minute(:timestamp, range: @range).calculate_all("SUM(value) / SUM(num)") }) if gc_data.present?
      @report_colors = ["#A5FFFF", "#EECC45", "#4E4318"]

      render :layout => false
    when "memory_physical"
      data = @application.event_data.where(:name => "Memory Usage")
      @report_data.push({ :name => "Memory Usage", :data => data.group_by_minute(:timestamp, range: @range).calculate_all("SUM(value) / SUM(num)") }) if data.present?
      @report_colors = ["#A5FFFF"]
      render :layout => false
    when "errors"
      data = @application.event_data.where(:name => "Error")
      @report_data.push({ :name => "Errors", :data => data.group_by_minute(:timestamp, range: @range).calculate_all("SUM(num)") }) if data.present?
      @report_colors = ["#D3DE00"]
      render :layout => false
    else
      render :json => @raw_datum
    end
  end

  def new
    data = Application.select("pg_sleep(5)").first

    render :json => data
  end

  def error
    raise 'Hello'
  end

  private

  def set_range
    @range = (Time.now - 10.minutes)..Time.now
  end
end
# frozen_string_literal: true

class EventsController < ApplicationController
  before_action :authenticate_user!, only: %i[new create]

  def index
    @events = Event.all
    render json: @events
  end

  def show
    @event = Event.find(params[:id])
  end

  def new
    @event = current_user.created_events.build
  end

  def edit
    @event = Event.find(params[:id])
  end

  def create
    @event = current_user.created_events.build(event_params)
    if @event.save
      redirect_to @event, notice: t('alerts.created')
    else
      render :new
    end
  end

  def update
    @event = Event.find(params[:id])
    if @event.update(event_params)
      redirect_to @event, notice: t('alerts.updated')
    else
      render :edit
    end
  end

  def destroy
    @event = Event.find(params[:id])
    @event.destroy
    redirect_to events_path, notice: t('alerts.deleted')
  end

  private

  def event_params
    params.require(:event).permit(:name, :description, :location, :date, :private, :category_id, :venue_id, :price, :capacity, :image)
  end
end

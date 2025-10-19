# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :users

  # Defines the root path route ("/")
  root 'home#index'

  resources :events
  resources :users, only: [:show]
  resources :attendances, only: %i[create destroy]
  resources :attendings, only: %i[create destroy]
  resources :invites, only: %i[create destroy]

  # API routes
  namespace :api do
    namespace :v1 do
      resources :events do
        resources :bookings, only: [:create]
      end
      
      resources :bookings, only: [:index, :show, :update] do
        member do
          patch :cancel
        end
      end

      namespace :users do
        get :profile
        get :events
        get :bookings
      end
    end
  end
end

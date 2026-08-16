# frozen_string_literal: true

Rails.application.routes.draw do
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  devise_for :users, controllers: { registrations: 'users/registrations' }

  # Backend root - redirect to ActiveAdmin dashboard
  root to: redirect('/admin')

  # Health check endpoints for container orchestrators
  get '/health', to: 'health#show'
  get '/up', to: 'health#show'

  # CSP violation reporting endpoint
  post '/csp-violation-report', to: proc { [204, {}, []] }

  resources :events
  resources :users, only: [:show]
  resources :attendances, only: %i[create destroy]
  resources :attendings, only: %i[create destroy]
  resources :invites, only: %i[create destroy]

  # API routes
  namespace :api do
    namespace :v1 do
      # Auth endpoints (no authentication required)
      post 'signup', to: 'registrations#create'
      post 'login', to: 'sessions#create'
      delete 'logout', to: 'sessions#destroy'

      resources :events do
        resources :orders, only: [:create]
      end

      resources :orders, only: %i[index show destroy] do
        member do
          post :checkout
        end
      end

      resources :tickets, only: [], param: :code do
        member do
          get :download
        end
      end

      resources :categories, only: [:index]
      resources :venues, only: [:index]

      resources :bookings, only: %i[index show] do
        member do
          patch :cancel
        end
      end

      # Stripe checkout endpoints
      scope 'checkout' do
        post 'webhook', to: 'checkout#webhook'
      end

      namespace :users do
        get :profile
        get :events
        get :bookings
      end
    end
  end
end

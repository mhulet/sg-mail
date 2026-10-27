Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resources :mailboxes, only: %i[index show new create destroy] do
    post :sync, on: :member
  end
  resources :messages, only: :show

  get "auth/google_oauth2" => "google_oauth#new", as: :google_oauth
  get "auth/google_oauth2/callback" => "google_oauth#callback"

  root "mailboxes#index"
end

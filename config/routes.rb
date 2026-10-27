Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  resource :session
  resources :passwords, param: :token
  get "invitations/:token" => "invitation_acceptances#show", as: :invitation_acceptance
  post "invitations/:token" => "invitation_acceptances#create"

  resources :accounts, only: %i[index new create]

  # Notifications Pub/Sub des boîtes Gmail (voir GmailWatch).
  post "webhooks/gmail" => "webhooks/gmail#create"

  # Adresse de retour fixe, déclarée dans la console Google.
  get "auth/google_oauth2/callback" => "google_oauth#callback"

  # Tout ce qui appartient à un client vit sous /<id du client>/.
  scope "/:account_id", constraints: { account_id: /\d+/ } do
    resources :mailboxes, only: %i[index show new create destroy] do
      post :sync, on: :member
      resources :accesses, controller: "mailbox_accesses", only: %i[index update]
    end
    resources :conversations, only: %i[index show] do
      post :unread, on: :member
      post :mark_all_read, on: :collection
    end
    resources :messages, only: :show do
      resources :attachments, only: %i[show create]
    end
    resources :memberships, only: %i[index update destroy]
    resources :invitations, only: %i[create destroy]
    get "auth/google_oauth2" => "google_oauth#new", as: :google_oauth
    get "/" => "conversations#index", as: :account_root
  end

  root "accounts#index"
end

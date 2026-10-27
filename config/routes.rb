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
      patch :assign, on: :member
      resources :notes, only: %i[create destroy]
      post :mark_all_read, on: :collection
    end
    resources :drafts, except: :show
    resource :search, only: :show
    resources :tasks, only: %i[index create update destroy]
    resources :messages, only: :show do
      resources :attachments, only: %i[show create]
    end
    resources :memberships, only: %i[index update destroy]
    resources :invitations, only: %i[create destroy]
    resources :api_tokens, only: %i[index create destroy]
    get "auth/google_oauth2" => "google_oauth#new", as: :google_oauth
    get "/" => "conversations#index", as: :account_root
  end

  # API JSON, utilisée par le CLI et le MCP (jeton personnel ; le client est celui du jeton).
  namespace :api do
    namespace :v1 do
      resource :me, only: :show, controller: "me"
      resources :conversations, only: %i[index show update] do
        post :read, on: :member
        post :unread, on: :member
        resources :notes, only: :create
      end
      resources :tasks, only: %i[index show create update]
      resources :drafts, only: %i[index show create update] do
        post :deliver, on: :member
      end
    end
  end

  # Serveur MCP pour Claude (même jeton que l'API).
  post "mcp" => "mcp#create", as: :mcp
  match "mcp" => "mcp#unsupported", via: %i[get delete]

  root "accounts#index"
end

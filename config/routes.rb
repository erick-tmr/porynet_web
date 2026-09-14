Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount LetterOpenerWeb::Engine, at: "/letters" if Rails.env.development?

  # OmniAuth callbacks cannot live under a dynamic segment, so they are drawn outside the
  # locale scope. `path: ""` collapses the mapping to "/", which puts them at /auth/:provider.
  # This call must come FIRST: the scoped `devise_for` below re-registers the :user mapping,
  # and only the last one survives with the failure app, path names and controllers.
  devise_for :users, path: "", only: :omniauth_callbacks,
             controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

  scope "(:locale)", locale: /en|pt/ do
    root "pages#home"

    # `path: ""` puts the account routes at the top level (/login, /register). Registrations are
    # declared by hand because the resourceful pair Devise would draw for them lands its create and
    # destroy verbs on "" itself, which is the landing page.
    devise_for :users,
               path: "",
               skip: [ :registrations, :omniauth_callbacks ],
               failure_app: "Users::FailureApp",
               path_names: { sign_in: "login", sign_out: "logout",
                             password: "password", confirmation: "confirmation" },
               controllers: { sessions: "users/sessions",
                              confirmations: "users/confirmations",
                              passwords: "users/passwords",
                              omniauth_callbacks: "users/omniauth_callbacks" }

    devise_scope :user do
      get  "register", to: "users/registrations#new",    as: :new_user_registration
      post "register", to: "users/registrations#create", as: :user_registration
      get  "register/finish", to: "users/omniauth_registrations#new",
           as: :new_user_omniauth_registration
      post "register/finish", to: "users/omniauth_registrations#create",
           as: :user_omniauth_registration
    end

    resource :account, only: :show
    scope :account, as: :account do
      get   "avatar", to: "accounts#avatar",        as: :avatar
      patch "avatar", to: "accounts#update_avatar"
      get   "security", to: "accounts#security", as: :security
      patch "security/email",    to: "accounts#update_email",    as: :security_email
      patch "security/password", to: "accounts#update_password", as: :security_password
      get "save",     to: "accounts#save_file", as: :save_file
      delete "security/identities/:provider", to: "accounts#disconnect_identity",
             as: :security_identity
    end

    post  "walkthroughs/:game/sync", to: "walkthrough_syncs#create", as: :walkthrough_sync
    patch "walkthroughs/:game/progress", to: "walkthrough_progress#update",
          as: :walkthrough_progress

    get "walkthroughs", to: "walkthroughs#index", as: :walkthroughs
    get "walkthroughs/:game", to: "walkthroughs#show", as: :walkthrough
    get "walkthroughs/:game/mew-glitch", to: "walkthroughs#mew_glitch", as: :walkthrough_mew_glitch
    get "walkthroughs/:game/:leg", to: "walkthroughs#leg", as: :walkthrough_leg
  end
end

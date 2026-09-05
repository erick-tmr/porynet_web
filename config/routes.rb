Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  mount LetterOpenerWeb::Engine, at: "/letters" if Rails.env.development?

  scope "(:locale)", locale: /en|pt/ do
    root "pages#home"

    # `path: ""` puts the account routes at the top level (/login, /register). Registrations are
    # declared by hand because the resourceful pair Devise would draw for them lands its create and
    # destroy verbs on "" itself, which is the landing page.
    devise_for :users,
               path: "",
               skip: [ :registrations ],
               failure_app: "Users::FailureApp",
               path_names: { sign_in: "login", sign_out: "logout",
                             password: "password", confirmation: "confirmation" },
               controllers: { sessions: "users/sessions",
                              confirmations: "users/confirmations",
                              passwords: "users/passwords" }

    devise_scope :user do
      get  "register", to: "users/registrations#new",    as: :new_user_registration
      post "register", to: "users/registrations#create", as: :user_registration
    end

    resource :account, only: :show

    get "walkthroughs", to: "walkthroughs#index", as: :walkthroughs
    get "walkthroughs/:game", to: "walkthroughs#show", as: :walkthrough
    get "walkthroughs/:game/mew-glitch", to: "walkthroughs#mew_glitch", as: :walkthrough_mew_glitch
    get "walkthroughs/:game/:leg", to: "walkthroughs#leg", as: :walkthrough_leg
  end
end

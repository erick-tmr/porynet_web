Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope "(:locale)", locale: /en|pt/ do
    root "pages#home"

    get "walkthroughs", to: "walkthroughs#index", as: :walkthroughs
    get "walkthroughs/:game", to: "walkthroughs#show", as: :walkthrough
    get "walkthroughs/:game/mew-glitch", to: "walkthroughs#mew_glitch", as: :walkthrough_mew_glitch
    get "walkthroughs/:game/:leg", to: "walkthroughs#leg", as: :walkthrough_leg
  end
end

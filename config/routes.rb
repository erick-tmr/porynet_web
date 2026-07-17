Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  scope "(:locale)", locale: /en|pt/ do
    root "pages#home"

    get "walkthroughs/:game", to: "walkthroughs#show", as: :walkthrough
    get "walkthroughs/:game/:location", to: "walkthroughs#location", as: :walkthrough_location
  end
end

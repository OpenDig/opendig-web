require 'rails_helper'

RSpec.describe "route for root path", type: :routing do
  it "routes / to areas#index" do
    expect(get: "/").to route_to(controller: "areas", action: "index")
  end
end

RSpec.describe "routes for SessionsController", type: :routing do
  it "routes /login to sessions#login" do
    expect(get: "/login").to route_to(controller: "sessions", action: "login")
  end

  it "routes /auth/:provider/callback to sessions#create" do
    expect(get: "/auth/test_provider/callback").to route_to(controller: "sessions", action: "create", provider: "test_provider")
  end

  it "routes /auth/failure to sessions#failure" do
    expect(get: "/auth/failure").to route_to(controller: "sessions", action: "failure")
  end

  it "routes /logout to sessions#destroy" do
    expect(delete: "/logout").to route_to(controller: "sessions", action: "destroy")
  end
end

RSpec.describe "routes for AreasController", type: :routing do
  it "routes /areas to areas#index" do
    expect(get: "/areas").to route_to(controller: "areas", action: "index")
  end

  it "routes /areas/new to areas#new" do
    expect(get: "/areas/new").to route_to(controller: "areas", action: "new")
  end

  it "routes POST /areas to areas#create" do
    expect(post: "/areas").to route_to(controller: "areas", action: "create")
  end
end

RSpec.describe "routes for SquaresController", type: :routing do
  it "routes /areas/:area_id/squares to squares#index" do
    expect(get: "/areas/1/squares").to route_to(controller: "squares", action: "index", area_id: "1")
  end

  it "routes /areas/:area_id/squares/new to squares#new" do
    expect(get: "/areas/1/squares/new").to route_to(controller: "squares", action: "new", area_id: "1")
  end

  it "routes POST /areas/:area_id/squares to squares#create" do
    expect(post: "/areas/1/squares").to route_to(controller: "squares", action: "create", area_id: "1")
  end
end

RSpec.describe "routes for PailsController", type: :routing do
  it "routes /areas/:area_id/squares/:square_id/pails to pails#index" do
    expect(get: "/areas/1/squares/2/pails").to route_to(controller: "pails", action: "index", area_id: "1", square_id: "2")
  end
end

RSpec.describe "routes for FindsController", type: :routing do
  it "routes /areas/:area_id/squares/:square_id/finds to finds#index" do
    expect(get: "/areas/1/squares/2/finds").to route_to(controller: "finds", action: "index", area_id: "1", square_id: "2")
  end
end

RSpec.describe "routes for LociController", type: :routing do
  it "routes /areas/:area_id/squares/:square_id/loci to loci#index" do
    expect(get: "/areas/1/squares/2/loci").to route_to(controller: "loci", action: "index", area_id: "1", square_id: "2")
  end

  it "routes /areas/:area_id/squares/:square_id/loci/new to loci#new" do
    expect(get: "/areas/1/squares/2/loci/new").to route_to(controller: "loci", action: "new", area_id: "1", square_id: "2")
  end

  it "routes POST /areas/:area_id/squares/:square_id/loci to loci#create" do
    expect(post: "/areas/1/squares/2/loci").to route_to(controller: "loci", action: "create", area_id: "1", square_id: "2")
  end

  it "routes /areas/:area_id/squares/:square_id/loci/:id to loci#show" do
    expect(get: "/areas/1/squares/2/loci/3").to route_to(controller: "loci", action: "show", area_id: "1", square_id: "2", id: "3")
  end

  it "routes /areas/:area_id/squares/:square_id/loci/:id/edit to loci#edit" do
    expect(get: "/areas/1/squares/2/loci/3/edit").to route_to(controller: "loci", action: "edit", area_id: "1", square_id: "2", id: "3")
  end

  it "routes PATCH /areas/:area_id/squares/:square_id/loci/:id to loci#update" do
    expect(patch: "/areas/1/squares/2/loci/3").to route_to(controller: "loci", action: "update", area_id: "1", square_id: "2", id: "3")
  end
end

RSpec.describe "routes for RegistrarController", type: :routing do
  it "routes /registrar to registrar#index" do
    expect(get: "/registrar").to route_to(controller: "registrar", action: "index")
  end

  it "routes /registrar/new to registrar#new" do
    expect(get: "/registrar/new").to route_to(controller: "registrar", action: "new")
  end

  it "routes POST /registrar to registrar#create" do
    expect(post: "/registrar").to route_to(controller: "registrar", action: "create")
  end
end

RSpec.describe "routes for BulkUploadsController", type: :routing do
  it "routes /bulk_uploads/new to bulk_uploads#new" do
    expect(get: "/bulk_uploads/new").to route_to(controller: "bulk_uploads", action: "new")
  end

  it "routes POST /bulk_uploads to bulk_uploads#create" do
    expect(post: "/bulk_uploads").to route_to(controller: "bulk_uploads", action: "create")
  end
end

RSpec.describe "routes for ReportsController", type: :routing do
  it "routes /reports to reports#index" do
    expect(get: "/reports").to route_to(controller: "reports", action: "index")
  end
  it "routes /reports/:id to reports#show" do
    expect(get: "/reports/1").to route_to(controller: "reports", action: "show", id: "1")
  end
end

module Progress
  Handover = Data.define(:pending, :url, :state) do
    def pending? = pending

    def adopted? = !pending
  end
end

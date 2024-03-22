defmodule DriversSeatCoop.Marketing.Campaigns.JoinCommunity do
  alias DriversSeatCoop.Marketing.CallToAction
  alias DriversSeatCoop.Marketing.Campaign
  alias DriversSeatCoop.Marketing.CampaignAction
  alias DriversSeatCoop.Marketing.CampaignPreview

  @campaign_id :join_community
  @whatsapp_invite_url "https://chat.whatsapp.com/LmRmBhGmko6AcHrG1pMjyT"

  def get_id, do: @campaign_id

  def instance do
    CallToAction.new(@campaign_id)
    |> Campaign.with_category(:info)
    |> Campaign.with_preview(
      CampaignPreview.new()
      |> CampaignPreview.with_title("Connect with Other Gig Workers")
      |> CampaignPreview.with_left_image_url("#{@campaign_id}/preview.png")
      |> CampaignPreview.with_action([
        CampaignAction.default_dismiss_tool(),
        CampaignAction.default_help_tool("I need help joining the Driver's Seat Community"),
        CampaignAction.new(:accept_preview, :accept, "Join our Community!")
        |> CampaignAction.with_url(@whatsapp_invite_url)
      ])
    )
  end
end

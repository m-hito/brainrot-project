local TweenService = game:GetService("TweenService")

function AnimateButton(rotation, scale)
	TweenService:Create(script.Parent,TweenInfo.new(0.25,Enum.EasingStyle.Back),{Rotation = rotation}):Play()
	TweenService:Create(script.Parent.UIScale,TweenInfo.new(0.25,Enum.EasingStyle.Back),{Scale = scale}):Play()
end

script.Parent.MouseEnter:Connect(function()
	AnimateButton(-15,1.1)
end)

script.Parent.MouseLeave:Connect(function()
	AnimateButton(0,1)
end)

script.Parent.MouseButton1Click:Connect(function()
	script.Parent.Parent.Visible = false
end)
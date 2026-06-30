try(
    local f = dotNetObject ""System.Windows.Forms.Form""
    local b = dotNetObject ""System.Windows.Forms.Button""
    b.Text = ""Test Button""
    b.Parent = f
    print (f.Controls.Count)
    f.Close()
) catch (
    print (getCurrentException())
)

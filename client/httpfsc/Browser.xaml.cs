using System.Windows;
using System.Windows.Controls;
using Flurl;
using httpfsc.Business.FileSystem.Http;

namespace httpfsc
{
    /// <summary>
    ///     Interaction logic for MainWindow.xaml
    /// </summary>
    public partial class Browser : Window
    {
        private readonly HttpFileSystemProxy _proxy;

        public Browser()
        {
            InitializeComponent();

            this.CurrentPath = "/";

            this.FolderListView.MouseDoubleClick +=
                (sender, args) => { Navigate(this.FolderListView.SelectedItem.ToString()); };
            
            _proxy = new HttpFileSystemProxy();
            RefreshList();
        }

        private Url CurrentPath { get; set; }

        private async void RefreshList()
        {
            var test = await _proxy.ListDirectory(this.CurrentPath);
            FolderListView.ItemsSource = test;
        }

        private void Navigate(Url path)
        {
            this.CurrentPath = path;
            this.RefreshList();
        }
    }
}
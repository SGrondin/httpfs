using System;

using httpfsc.Business.Http;

namespace Httpfs.Client
{
    /// <summary>
    /// Main browser window
    /// </summary>
    public partial class Browser
    {
        #region Fields

        private readonly HttpFileSystemProxy _proxy;
        private readonly ClientConfig _config;

        #endregion

        #region Constructors

        public Browser()
        {
            this.InitializeComponent();

            this.CurrentPath = "/";

            this.FolderListView.MouseDoubleClick +=
                (sender, args) => this.RefreshList(this.CurrentPath.Combine(this.FolderListView.SelectedItem.ToString()));

            this.CurrentFolderListView.MouseDoubleClick +=
                (sender, args) => this.DownloadSelectedFile();

            this._config = new ClientConfig();
            this._proxy = new HttpFileSystemProxy(this._config);
            this.RefreshList();
        }

        #endregion

        #region Properties

        private Url CurrentPath { get; set; }

        #endregion

        #region Methods

        private async void RefreshList(Url path = null)
        {
            if (path != null)
            {
                this.CurrentPath = path;
            }

            var test = await this._proxy.ListDirectory(this.CurrentPath);
            this.FolderListView.ItemsSource = test.Folders;
            this.CurrentFolderListView.ItemsSource = test.Files;
        }

        private void DownloadSelectedFile()
        {
            var selectedFile = this.CurrentFolderListView.SelectedItem.ToString();

            if (string.IsNullOrEmpty(selectedFile))
            {
                return;
            }

            var absoluteSelectedPath = this.CurrentPath.Combine(selectedFile);
            
            var downloadToUrl = this._config.LocalRoot
                .Combine(this.CurrentPath)
                .Combine(selectedFile);

            this._proxy.DownloadFile(absoluteSelectedPath, downloadToUrl);
        }

        #endregion
    }
}
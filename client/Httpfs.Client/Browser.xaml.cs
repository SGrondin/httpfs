using System;
using System.Net;
using System.Windows;

using httpfsc.Business.Http;
using httpfsc.Business.Http.FileSystem.Exceptions;

using Httpfs.Client.UI;

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

            this.CurrentFolderListView.MouseDoubleClick += (sender, args) => this.DownloadSelectedFile();

            this.FileMenuCreate.Click += async (sender, args) =>
            {
                var ans = await InputDialog.Ask("File name?", "Create new file");
                if (string.IsNullOrWhiteSpace(ans)) return;

                this._proxy.CreateNew(this.CurrentPath.Combine(ans), DefaultHttpErrorHandler);
            };

            this._config = new ClientConfig();
            this._proxy = new HttpFileSystemProxy(this._config);

            this.RefreshList();
        }

        #endregion

        #region Properties

        private static Action<HttpStatusCode, string> DefaultHttpErrorHandler
        {
            get
            {
                return (code, description) => MessageBox.Show(description, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private Url CurrentPath { get; set; }

        #endregion

        #region Methods

        private async void RefreshList(Url path = null)
        {
            if (path != null)
            {
                this.CurrentPath = path;
            }

            var result = await this._proxy.ListDirectory(this.CurrentPath, DefaultHttpErrorHandler);

            this.FolderListView.ItemsSource = result.Folders;
            this.CurrentFolderListView.ItemsSource = result.Files;
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

            this._proxy.DownloadFile(absoluteSelectedPath, downloadToUrl, DefaultHttpErrorHandler);
        }

        #endregion
    }
}
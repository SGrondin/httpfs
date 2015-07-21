using System;
using System.Windows;

using Flurl;

using Httpfs.Client.Business.FileSystem.Http;

namespace Httpfs.Client
{
    /// <summary>
    /// Interaction logic for MainWindow
    /// </summary>
    public partial class Browser
    {
        #region Fields

        private readonly HttpFileSystemProxy _proxy;
        private readonly ClientConfig _config;

        private Url _currentPath;

        #endregion

        #region Constructors

        public Browser()
        {
            this.InitializeComponent();

            this.CurrentPath = "/";

            this.FolderListView.MouseDoubleClick +=
                (sender, args) => this.RefreshList(this.FolderListView.SelectedItem.ToString());

            this.CurrentFolderListView.MouseDoubleClick +=
                (sender, args) => this.DownloadSelectedFile();

            this._config = new ClientConfig();
            this._proxy = new HttpFileSystemProxy(this._config);
            this.RefreshList();
        }

        #endregion

        #region Properties

        private Url CurrentPath
        {
            get { return new Url(this._currentPath); }
            set { this._currentPath = value; }
        }

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

            var absoluteSelectedPath = this.CurrentPath
                .AppendPathSegment(selectedFile);

            var downloadToUrl = this._config.LocalRoot
                .AppendPathSegment(this.CurrentPath)
                .AppendPathSegment(selectedFile);

            this._proxy.DownloadFile(absoluteSelectedPath, downloadToUrl);
        }

        #endregion
    }
}
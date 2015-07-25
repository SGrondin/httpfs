using System;
using System.IO;
using System.Linq;
using System.Net;
using System.Text;
using System.Threading.Tasks;
using System.Windows;

using Httpfs.Client.UI;

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

            this.FolderListView.MouseDoubleClick += (sender, args) =>
            {
                if (this.FolderListView.SelectedItem == null) return;

                this.RefreshList(this.CurrentPath.Combine(this.FolderListView.SelectedItem.ToString()));
            };

            this.FileListView.MouseDoubleClick += (sender, args) =>
            {
                if (this.FileListView.SelectedItem == null) return;

                this.DownloadSelectedFile(this.CurrentPath.Combine(this.FileListView.SelectedItem.ToString()));
            };

            this.FileListView.Drop += async (sender, args) =>
            {
                var files = (string[])args.Data.GetData(DataFormats.FileDrop);
                await Task.WhenAll(files.Select(f => this.UploadFile(this.CurrentPath, f)));
                this.RefreshList();
            };

            this.RefreshFolderContextMenuItem.Click += (sender, args) => this.RefreshList();
            this.RefreshFileContextMenuItem.Click += (sender, args) => this.RefreshList();

            this.CreateFolderContextMenuItem.Click += async (sender, args) =>
            {
                await this.CreateFolder();
                this.RefreshList();
            };

            this.CreateEmptyFilerContextMenuItem.Click += async (sender, args) =>
            {
                await this.CreateEmptyFile();
                this.RefreshList();
            };

            this.FileMenuCreateEmptyFile.Click += async (sender, args) =>
            {
                await this.CreateEmptyFile();
                this.RefreshList();
            };

            this.FileMenuCreateFolder.Click += async (sender, args) =>
            {
                await this.CreateFolder();
                this.RefreshList();
            };

            this.DeleteFileContextMenuItem.Click += async (sender, args) =>
            {
                await Task.WhenAll(this.FileListView.SelectedItems.Cast<Url>().Select(this.DeleteFile));
                this.RefreshList();
            };

            this.DeleteFolderContextMenuItem.Click += async (sender, args) =>
            {
                await Task.WhenAll(this.FolderListView.SelectedItems.Cast<Url>().Select(this.DeleteFolder));
                this.RefreshList();
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
                return (code, description) =>
                {
                    if (code != HttpStatusCode.OK)
                    {
                        MessageBox.Show(description, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                };
            }
        }

        private Url CurrentPath { get; set; }

        #endregion

        #region Methods

        private async Task DeleteFile(Url path)
        {
            await this._proxy.DeleteFile(this.CurrentPath.Combine(path), DefaultHttpErrorHandler);
        }

        private async Task DeleteFolder(Url path)
        {
            await this._proxy.DeleteFolder(this.CurrentPath.Combine(path), DefaultHttpErrorHandler);
        }

        private async Task CreateEmptyFile()
        {
            var ans = await InputDialog.Ask("File name?", "Create new file");
            if (string.IsNullOrWhiteSpace(ans))
            {
                return;
            }

            await this._proxy.CreateEmptyFile(this.CurrentPath.Combine(ans), DefaultHttpErrorHandler);
        }

        private async Task CreateFolder()
        {
            var ans = await InputDialog.Ask("Folder name?", "Create new folder");
            if (string.IsNullOrWhiteSpace(ans))
            {
                return;
            }

            await this._proxy.CreateFolder(this.CurrentPath.Combine(ans), DefaultHttpErrorHandler);
        }

        private async void RefreshList(Url path = null)
        {
            if (path != null)
            {
                this.CurrentPath = path;
            }

            var result = await this._proxy.ListDirectory(this.CurrentPath, DefaultHttpErrorHandler);

            this.FolderListView.ItemsSource = result.Folders.OrderBy(f => f.ToString());
            this.FileListView.ItemsSource = result.Files.OrderBy(f => f.GetFileName());
        }

        private void DownloadSelectedFile(Url path)
        {
            var downloadToUrl = this._config.LocalRoot.Combine(path);

            this._proxy.DownloadFile(path, downloadToUrl, DefaultHttpErrorHandler);
        }

        private async Task UploadFile(Url folder, Url path)
        {
            var to = folder.Combine(path.GetFileName());
            var file = File.ReadAllText(path, Encoding.Default);

            await this._proxy.UploadFile(to, file, DefaultHttpErrorHandler);
        }

        #endregion
    }
}
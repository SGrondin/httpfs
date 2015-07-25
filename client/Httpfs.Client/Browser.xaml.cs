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
                if (this.FileListView.SelectedItem == null) return;

                this.RefreshList(this.CurrentPath.Combine(this.FolderListView.SelectedItem.ToString()));
            };

            this.FileListView.MouseDoubleClick += (sender, args) => this.DownloadSelectedFile();

            this.FileListView.Drop += async (sender, args) =>
            {
                var files = (string[])args.Data.GetData(DataFormats.FileDrop);

                if (files.Length > 0)
                {
                    var urls = files.Select(f => new Url(f));

                    foreach (var url in urls)
                    {
                        await this.UploadFile(this.CurrentPath, url);
                    }
                }

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
                if (this.FileListView.SelectedItem == null) return;

                await this.DeleteFile(this.FileListView.SelectedItem.ToString());
                this.RefreshList();
            };

            this.DeleteFolderContextMenuItem.Click += async (sender, args) =>
            {
                if (this.FolderListView.SelectedItem == null) return;

                await this.DeleteFolder(this.FolderListView.SelectedItem.ToString());
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

            this.FolderListView.ItemsSource = result.Folders;
            this.FileListView.ItemsSource = result.Files;
        }

        private void DownloadSelectedFile()
        {
            var selectedFile = this.FileListView.SelectedItem.ToString();

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

        private async Task UploadFile(Url folder, Url path)
        {
            var to = folder.Combine(path.GetFileName());
            var file = File.ReadAllText(path, Encoding.Default);

            await this._proxy.UploadFile(to, file, DefaultHttpErrorHandler);
        }

        #endregion
    }
}